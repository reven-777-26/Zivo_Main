document.addEventListener('DOMContentLoaded', () => {
    // 1. Screenshot Slideshow Logic
    const screenshots = document.querySelectorAll('.screenshot');
    let currentSlide = 0;
    const slideInterval = 3000; // 3 seconds

    function nextSlide() {
        // Identify outgoing slide
        const activeSlide = screenshots[currentSlide];
        
        // Reset previous classes
        screenshots.forEach(s => s.classList.remove('previous'));
        
        // Flag outgoing slide as previous
        activeSlide.classList.add('previous');
        activeSlide.classList.remove('active');
        
        // Calculate index of next slide
        currentSlide = (currentSlide + 1) % screenshots.length;
        
        // Add active class to next slide
        screenshots[currentSlide].classList.add('active');
    }

    if (screenshots.length > 1) {
        setInterval(nextSlide, slideInterval);
    }

    // 3. Email Form Validation and Modal Success Flows
    const signupForm = document.getElementById('signup-form');
    const emailInput = document.getElementById('email-input');
    const formFeedback = document.getElementById('form-feedback');
    const successModal = document.getElementById('success-modal');
    const closeModalBtn = document.getElementById('close-modal-btn');
    const registeredEmailSpan = document.getElementById('registered-email');

    function validateEmail(email) {
        const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return re.test(email);
    }

    signupForm.addEventListener('submit', (e) => {
        e.preventDefault();
        
        const emailVal = emailInput.value.trim();
        
        if (!emailVal) {
            showFeedback('Please enter an email address.', 'error');
            return;
        }

        if (!validateEmail(emailVal)) {
            showFeedback('Please enter a valid email address.', 'error');
            return;
        }

        // Mimic API post delay
        const submitBtn = signupForm.querySelector('button[type="submit"]');
        const originalBtnHTML = submitBtn.innerHTML;
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<span>Processing...</span>';

        setTimeout(() => {
            // Success response simulation
            submitBtn.disabled = false;
            submitBtn.innerHTML = originalBtnHTML;
            
            // Pop success modal
            registeredEmailSpan.textContent = emailVal;
            successModal.classList.add('active');
            
            // Reset input and feedback
            emailInput.value = '';
            formFeedback.style.display = 'none';
        }, 1200);
    });

    function showFeedback(message, type) {
        formFeedback.textContent = message;
        formFeedback.className = 'form-feedback ' + type;
    }

    // Modal dismiss controls
    closeModalBtn.addEventListener('click', () => {
        successModal.classList.remove('active');
    });

    successModal.addEventListener('click', (e) => {
        if (e.target === successModal) {
            successModal.classList.remove('active');
        }
    });

    // 4. Scroll CTA triggers
    const scrollTopTrigger = document.querySelector('.scroll-top-trigger');
    scrollTopTrigger.addEventListener('click', () => {
        window.scrollTo({
            top: 0,
            behavior: 'smooth'
        });
        // Highlight the email input for focus
        setTimeout(() => {
            emailInput.focus();
        }, 500);
    });
});
