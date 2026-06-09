import {setGlobalOptions} from "firebase-functions";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {GoogleGenAI} from "@google/genai";

setGlobalOptions({maxInstances: 10});

export const healthCheckAI = onCall({
  secrets: ["GEMINI_API_KEY"],
  invoker: "public",
}, async () => {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
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
    const reply = response.text ?
      response.text.trim() : "";
    return {status: "working", response: reply};
  } catch (error: unknown) {
    const errMsg = error instanceof Error ?
      error.message :
      "Failed to communicate with Gemini API.";
    throw new HttpsError("internal", errMsg);
  }
});

export const analyzeMeal = onCall({
  secrets: ["GEMINI_API_KEY"],
  invoker: "public",
}, async (request) => {
  const data = request.data;
  if (!data || !data.type || !data.content) {
    throw new HttpsError(
      "invalid-argument",
      "Must have 'type' and 'content'."
    );
  }
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition",
      "Gemini API key not configured."
    );
  }
  try {
    const ai = new GoogleGenAI({apiKey});
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let contents: any[] = [];
    let config: Record<string, unknown>;
    const mealSchema = {
      type: "OBJECT",
      properties: {
        foodName: {
          type: "STRING",
          description: "The name of the food.",
        },
        calories: {
          type: "INTEGER",
          description: "Estimated calories.",
        },
        protein: {
          type: "INTEGER",
          description: "Estimated protein in g.",
        },
        carbs: {
          type: "INTEGER",
          description: "Estimated carbs in g.",
        },
        fat: {
          type: "INTEGER",
          description: "Estimated fat in g.",
        },
      },
      required: [
        "foodName",
        "calories",
        "protein",
        "carbs",
        "fat",
      ],
    };
    if (data.type === "barcode_image") {
      contents = [
        {
          inlineData: {
            mimeType: "image/jpeg",
            data: data.content,
          },
        },
        {
          text: "Read the barcode digits. " +
            "Return JSON with 'barcode'.",
        },
      ];
      config = {
        responseMimeType: "application/json",
        responseSchema: {
          type: "OBJECT",
          properties: {
            barcode: {
              type: "STRING",
              description: "Barcode digits.",
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
          text: "Analyze this food image. " +
            "Estimate name, cals, protein, " +
            "carbs, fat.",
        },
      ];
      config = {
        responseMimeType: "application/json",
        responseSchema: mealSchema,
      };
    } else if (
      data.type === "text" ||
      data.type === "voice"
    ) {
      const desc = data.content;
      contents = [
        {
          text: "Analyze this meal: " +
            `"${desc}". Estimate name, ` +
            "cals, protein, carbs, fat.",
        },
      ];
      config = {
        responseMimeType: "application/json",
        responseSchema: mealSchema,
      };
    } else {
      throw new HttpsError(
        "invalid-argument",
        `Unsupported type: ${data.type}`
      );
    }
    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents: contents,
      config: config,
    });
    const reply = response.text ?
      response.text.trim() : "";
    if (!reply) {
      throw new Error("Empty Gemini response.");
    }
    const parsed = JSON.parse(reply);
    if (data.type === "barcode_image") {
      return {barcode: parsed.barcode || ""};
    }
    return {
      foodName: parsed.foodName || "Unknown Food",
      calories: Number(parsed.calories) || 0,
      protein: Number(parsed.protein) || 0,
      carbs: Number(parsed.carbs) || 0,
      fat: Number(parsed.fat) || 0,
    };
  } catch (error: unknown) {
    logger.error("analyzeMeal error:", error);
    const errMsg = error instanceof Error ?
      error.message : "Failed to analyze meal.";
    throw new HttpsError("internal", errMsg);
  }
});

/**
 * identifyProduct - Step 1
 * Uses Gemini vision to identify product
 * name, brand, and category from an image.
 */
export const identifyProduct = onCall({
  secrets: ["GEMINI_API_KEY"],
  invoker: "public",
}, async (request) => {
  const data = request.data;
  if (!data || !data.imageBase64) {
    throw new HttpsError(
      "invalid-argument",
      "Must provide 'imageBase64'."
    );
  }
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition",
      "Gemini API key not configured."
    );
  }
  try {
    const ai = new GoogleGenAI({apiKey});
    const prompt = [
      "You are a product identification expert.",
      "Look at this product image carefully.",
      "",
      "Identify:",
      "1. Exact product name with variant/size",
      "2. Brand name",
      "3. Category: food, supplement, skincare",
      "   food = packaged foods, snacks, drinks",
      "   supplement = protein, vitamins, etc",
      "   skincare = face wash, serum, etc",
      "",
      "If this is an ingredient label,",
      "identify from visible text.",
      "Be specific. Do not guess generic names.",
    ].join("\n");

    const contents = [
      {
        inlineData: {
          mimeType: "image/jpeg",
          data: data.imageBase64,
        },
      },
      {text: prompt},
    ];

    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents: contents,
      config: {
        responseMimeType: "application/json",
        responseSchema: {
          type: "OBJECT",
          properties: {
            productName: {
              type: "STRING",
              description: "Exact product name",
            },
            brand: {
              type: "STRING",
              description: "Brand name",
            },
            category: {
              type: "STRING",
              description: "food/supplement/skincare",
            },
            ingredients: {
              type: "ARRAY",
              items: {type: "STRING"},
              description: "Ingredients if visible",
            },
          },
          required: [
            "productName",
            "brand",
            "category",
          ],
        },
      },
    });

    const reply = response.text ?
      response.text.trim() : "";
    logger.info("identifyProduct:", reply);
    if (!reply) {
      throw new Error("Empty Gemini response.");
    }
    return JSON.parse(reply);
  } catch (error: unknown) {
    logger.error("identifyProduct error:", error);
    const errMsg = error instanceof Error ?
      error.message : "Failed to identify product.";
    throw new HttpsError("internal", errMsg);
  }
});

/**
 * analyzeVisionProduct - Step 2
 * Deep AI health analysis of product data.
 * Returns structured health insights.
 */
export const analyzeVisionProduct = onCall({
  secrets: ["GEMINI_API_KEY"],
  invoker: "public",
}, async (request) => {
  const data = request.data;
  if (!data || !data.category || !data.payload) {
    throw new HttpsError(
      "invalid-argument",
      "Need 'category' and 'payload'."
    );
  }
  const category = data.category;
  const payload = data.payload;
  const image = data.imageBase64;
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition",
      "Gemini API key not configured."
    );
  }
  try {
    const ai = new GoogleGenAI({apiKey});
    const payloadStr = JSON.stringify(payload);
    let prompt = "";

    if (category === "Food") {
      prompt = buildFoodPrompt(payloadStr);
    } else if (category === "Supplement") {
      prompt = buildSupplementPrompt(payloadStr);
    } else if (category === "Skincare") {
      prompt = buildSkincarePrompt(payloadStr);
    } else {
      throw new HttpsError(
        "invalid-argument",
        `Unsupported category: ${category}`
      );
    }

    const schema = buildAnalysisSchema();

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let contents: any[] = [{text: prompt}];
    if (image) {
      contents = [
        {
          inlineData: {
            mimeType: "image/jpeg",
            data: image,
          },
        },
        {text: prompt},
      ];
    }

    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents: contents,
      config: {
        responseMimeType: "application/json",
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        responseSchema: schema as any,
      },
    });

    const reply = response.text ?
      response.text.trim() : "";
    logger.info("analyzeVisionProduct:", reply);
    if (!reply) {
      throw new Error("Empty Gemini response.");
    }
    return JSON.parse(reply);
  } catch (error: unknown) {
    logger.error("analyzeVisionProduct err:", error);
    const errMsg = error instanceof Error ?
      error.message : "Failed to analyze.";
    throw new HttpsError("internal", errMsg);
  }
});

/**
 * Build food analysis prompt.
 * @param {string} payloadStr - product data
 * @return {string} prompt text
 */
function buildFoodPrompt(payloadStr: string): string {
  return [
    "You are an AI Health Advisor for Zivo.",
    "Analyze this food product IN DEPTH",
    "like a nutritionist would.",
    "",
    `Product Data: ${payloadStr}`,
    "",
    "YOUR JOB:",
    "1. Calculate Zivo Health Score (0-100).",
    "2. Assign grade A/B/C/D/E.",
    "3. Write verdict (MAX 12 words).",
    "4. Generate 3-5 insights starting with",
    "   emoji: ❌ ⚠ or ✅",
    "5. Decode EVERY ingredient - check for",
    "   sneaky sugar names (maltodextrin,",
    "   dextrose, HFCS, invert sugar, etc),",
    "   palm oil (palmitate, palmitic acid,",
    "   vegetable fat, etc), and additives.",
    "6. Mark each ingredient safety as",
    "   Safe, Caution, or Avoid.",
    "7. Recommend 3 REAL healthier",
    "   alternatives from Indian markets",
    "   (Yoga Bar, True Elements, etc).",
    "",
    "IMPORTANT: Do NOT dump raw numbers.",
    "Instead of 'sugar: 28g', say",
    "'Contains enough sugar to cause a",
    "significant glucose spike.'",
    "Think like a health coach.",
  ].join("\n");
}

/**
 * Build supplement analysis prompt.
 * @param {string} payloadStr - product data
 * @return {string} prompt text
 */
function buildSupplementPrompt(
  payloadStr: string
): string {
  return [
    "You are an AI Health Advisor for Zivo.",
    "Analyze this supplement product",
    "like a sports nutritionist would.",
    "",
    `Product Data: ${payloadStr}`,
    "",
    "YOUR JOB:",
    "1. Calculate Zivo Score (0-100).",
    "2. Assign grade A/B/C/D/E.",
    "3. Write verdict (MAX 12 words).",
    "4. Generate 3-5 insights starting with",
    "   emoji: ❌ ⚠ or ✅",
    "5. Decode EVERY ingredient. Check for",
    "   sucralose, aspartame, acesulfame-K,",
    "   fillers (magnesium stearate, etc),",
    "   artificial colors (Red 40, etc).",
    "6. Mark safety: Safe, Caution, Avoid.",
    "7. Recommend 3 REAL alternatives from",
    "   Indian brands (Nutrabay, AS-IT-IS,",
    "   MuscleBlaze Raw, Avvatar, etc).",
    "",
    "Focus on purity, bioavailability,",
    "filler content, sweetener quality.",
  ].join("\n");
}

/**
 * Build skincare analysis prompt.
 * @param {string} payloadStr - product data
 * @return {string} prompt text
 */
function buildSkincarePrompt(
  payloadStr: string
): string {
  return [
    "You are an AI Skin Advisor for Zivo.",
    "Analyze this skincare product",
    "like a dermatologist would.",
    "",
    `Product Data: ${payloadStr}`,
    "",
    "YOUR JOB:",
    "1. Calculate Zivo Skin Score (0-100).",
    "2. Assign grade A/B/C/D/E.",
    "3. Write verdict (MAX 12 words).",
    "4. Generate 3-5 insights starting with",
    "   emoji: ❌ ⚠ or ✅",
    "5. Decode EVERY ingredient. Check for",
    "   acne triggers, drying alcohols,",
    "   fragrance/parfum, parabens,",
    "   sulfates, silicones.",
    "6. Mark safety: Safe, Caution, Avoid.",
    "7. Recommend 3 REAL alternatives from",
    "   brands in India (Minimalist,",
    "   Cetaphil, CeraVe, Plum, etc).",
    "",
    "Focus on comedogenicity, irritation,",
    "barrier health, pregnancy safety.",
  ].join("\n");
}

/**
 * Build Gemini response schema.
 * @return {Record<string, unknown>} schema
 */
function buildAnalysisSchema(): Record<string, unknown> {
  return {
    type: "OBJECT",
    properties: {
      productName: {type: "STRING"},
      brand: {type: "STRING"},
      zivoScore: {type: "INTEGER"},
      healthGrade: {
        type: "STRING",
        description: "One of A, B, C, D, E",
      },
      verdict: {
        type: "STRING",
        description: "Max 12 word verdict",
      },
      insights: {
        type: "ARRAY",
        items: {type: "STRING"},
        description: "3-5 key insights",
      },
      decodedIngredients: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          properties: {
            name: {type: "STRING"},
            sneakyNameFor: {
              type: "STRING",
              description:
                "Sugar/PalmOil/Carbs/None",
            },
            meaning: {type: "STRING"},
            safety: {
              type: "STRING",
              description: "Safe/Caution/Avoid",
            },
            description: {type: "STRING"},
          },
          required: [
            "name",
            "sneakyNameFor",
            "meaning",
            "safety",
            "description",
          ],
        },
      },
      alternatives: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          properties: {
            name: {type: "STRING"},
            brand: {type: "STRING"},
            reason: {type: "STRING"},
            healthGrade: {type: "STRING"},
          },
          required: [
            "name",
            "brand",
            "reason",
            "healthGrade",
          ],
        },
      },
      sugarAnalysis: {
        type: "OBJECT",
        properties: {
          impact: {type: "STRING"},
          amount: {type: "STRING"},
          hiddenNamesDetected: {
            type: "ARRAY",
            items: {type: "STRING"},
          },
          verdict: {type: "STRING"},
        },
        required: [
          "impact",
          "amount",
          "hiddenNamesDetected",
          "verdict",
        ],
      },
      palmOilAnalysis: {
        type: "OBJECT",
        properties: {
          present: {type: "BOOLEAN"},
          ingredientsDetected: {
            type: "ARRAY",
            items: {type: "STRING"},
          },
          verdict: {type: "STRING"},
        },
        required: [
          "present",
          "ingredientsDetected",
          "verdict",
        ],
      },
      carbsAnalysis: {
        type: "OBJECT",
        properties: {
          impact: {type: "STRING"},
          amount: {type: "STRING"},
          verdict: {type: "STRING"},
        },
        required: ["impact", "amount", "verdict"],
      },
    },
    required: [
      "productName",
      "brand",
      "zivoScore",
      "healthGrade",
      "verdict",
      "insights",
      "decodedIngredients",
      "alternatives",
      "sugarAnalysis",
      "palmOilAnalysis",
      "carbsAnalysis",
    ],
  };
}
