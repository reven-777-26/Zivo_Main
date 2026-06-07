import {setGlobalOptions} from "firebase-functions";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {GoogleGenAI} from "@google/genai";

// For cost control and performance optimization
setGlobalOptions({maxInstances: 10});

/**
 * healthCheckAI
 * Callable function v2 that reads GEMINI_API_KEY from Firebase Secret Manager,
 * queries the Gemini API with "Reply ONLY with WORKING", and returns the
 * status/response.
 */
export const healthCheckAI = onCall({
  secrets: ["GEMINI_API_KEY"],
  invoker: "public",
}, async () => {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    logger.error("GEMINI_API_KEY is not defined in the environment.");
    throw new HttpsError(
      "failed-precondition",
      "The Gemini API key is not configured."
    );
  }

  try {
    const ai = new GoogleGenAI({apiKey});
    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents: "Reply ONLY with WORKING",
    });

    const reply = response.text ? response.text.trim() : "";
    logger.info("Gemini Health Check Response:", reply);

    return {
      status: "working",
      response: reply,
    };
  } catch (error: unknown) {
    logger.error("Error communicating with Gemini API:", error);
    const errMsg = error instanceof Error ?
      error.message : "Failed to communicate with Gemini API.";
    throw new HttpsError("internal", errMsg);
  }
});

/**
 * analyzeMeal
 * Callable function v2 that accepts a meal payload
 * and returns the structured Standard Food Object using Gemini.
 */
export const analyzeMeal = onCall({
  secrets: ["GEMINI_API_KEY"],
  invoker: "public",
}, async (request) => {
  const data = request.data;

  if (!data || !data.type || !data.content) {
    logger.warn("analyzeMeal called with invalid input:", data);
    throw new HttpsError(
      "invalid-argument",
      "The function must be called with an object containing " +
      "'type' and 'content'."
    );
  }

  logger.info(`analyzeMeal received input type: ${data.type}`);

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    logger.error("GEMINI_API_KEY is not defined in the environment.");
    throw new HttpsError(
      "failed-precondition",
      "The Gemini API key is not configured."
    );
  }

  try {
    const ai = new GoogleGenAI({apiKey});

    let contents: Record<string, unknown>[] = [];
    let config: Record<string, unknown>;

    if (data.type === "barcode_image") {
      contents = [
        {
          inlineData: {
            mimeType: "image/jpeg",
            data: data.content,
          },
        },
        {
          text: "Read the barcode digits in this image. " +
            "Return a JSON object containing the barcode number " +
            "under 'barcode'.",
        },
      ];
      config = {
        responseMimeType: "application/json",
        responseSchema: {
          type: "OBJECT",
          properties: {
            barcode: {
              type: "STRING",
              description: "The barcode digits read from the image.",
            },
          },
          required: ["barcode"],
        },
      };
    } else if (data.type === "image") {
      contents = [
        {
          inlineData: {
            mimeType: "image/jpeg",
            data: data.content,
          },
        },
        {
          text: "Analyze this image of food and estimate its " +
            "name, calories, protein, carbs, and fat contents.",
        },
      ];
      config = {
        responseMimeType: "application/json",
        responseSchema: {
          type: "OBJECT",
          properties: {
            foodName: {
              type: "STRING",
              description: "The name of the food item or meal.",
            },
            calories: {
              type: "INTEGER",
              description: "Estimated calories in kcal.",
            },
            protein: {
              type: "INTEGER",
              description: "Estimated protein in grams.",
            },
            carbs: {
              type: "INTEGER",
              description: "Estimated carbohydrates in grams.",
            },
            fat: {
              type: "INTEGER",
              description: "Estimated fat in grams.",
            },
          },
          required: ["foodName", "calories", "protein", "carbs", "fat"],
        },
      };
    } else if (data.type === "text" || data.type === "voice") {
      contents = [
        {
          text: `Analyze the following meal description: "${data.content}". ` +
            "Estimate its name, calories, protein, carbs, and fat contents.",
        },
      ];
      config = {
        responseMimeType: "application/json",
        responseSchema: {
          type: "OBJECT",
          properties: {
            foodName: {
              type: "STRING",
              description: "The name of the food item or meal.",
            },
            calories: {
              type: "INTEGER",
              description: "Estimated calories in kcal.",
            },
            protein: {
              type: "INTEGER",
              description: "Estimated protein in grams.",
            },
            carbs: {
              type: "INTEGER",
              description: "Estimated carbohydrates in grams.",
            },
            fat: {
              type: "INTEGER",
              description: "Estimated fat in grams.",
            },
          },
          required: ["foodName", "calories", "protein", "carbs", "fat"],
        },
      };
    } else {
      throw new HttpsError(
        "invalid-argument",
        `Unsupported input type: ${data.type}`
      );
    }

    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents: contents,
      config: config,
    });

    const reply = response.text ? response.text.trim() : "";
    logger.info("Gemini analyzeMeal Response:", reply);

    if (!reply) {
      throw new Error("Empty response from Gemini API.");
    }

    const parsed = JSON.parse(reply);
    if (data.type === "barcode_image") {
      return {
        barcode: parsed.barcode || "",
      };
    }
    return {
      foodName: parsed.foodName || "Unknown Food",
      calories: Number(parsed.calories) || 0,
      protein: Number(parsed.protein) || 0,
      carbs: Number(parsed.carbs) || 0,
      fat: Number(parsed.fat) || 0,
    };
  } catch (error: unknown) {
    logger.error("Error communicating with Gemini API in analyzeMeal:", error);
    const errMsg = error instanceof Error ?
      error.message : "Failed to analyze meal.";
    throw new HttpsError("internal", errMsg);
  }
});


