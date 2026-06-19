/* ==========================================================================
   ZIVO LANDING PAGE INTERACTIVITY
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {

    // --- 1. MOBILE NAVIGATION ---
    const mobileNavToggle = document.querySelector('.mobile-nav-toggle');
    const mobileNavDrawer = document.querySelector('.mobile-nav-drawer');
    const mobileLinks = document.querySelectorAll('.mobile-nav-link');

    if (mobileNavToggle && mobileNavDrawer) {
        mobileNavToggle.addEventListener('click', () => {
            mobileNavToggle.classList.toggle('open');
            mobileNavDrawer.classList.toggle('open');
            document.body.classList.toggle('no-scroll');
        });

        // Close drawer when clicking a link
        mobileLinks.forEach(link => {
            link.addEventListener('click', () => {
                mobileNavToggle.classList.remove('open');
                mobileNavDrawer.classList.remove('open');
                document.body.classList.remove('no-scroll');
            });
        });
    }


    // --- 2. STICKY NAV BACKGROUND ---
    const header = document.querySelector('.site-header');

    const handleScroll = () => {
        if (window.scrollY > 20) {
            header.classList.add('scrolled');
        } else {
            header.classList.remove('scrolled');
        }
    };

    window.addEventListener('scroll', handleScroll);
    handleScroll(); // Check on init


    // --- 3. ANALYZER INTERACTIVE SCAN DEMO ---
    const demoTabs = document.querySelectorAll('.demo-tab');
    const laser = document.querySelector('.analyzer-visual .scanner-laser');

    demoTabs.forEach(tab => {
        tab.addEventListener('click', () => {
            // Remove active state from all tabs
            demoTabs.forEach(t => t.classList.remove('active'));
            // Add active state to clicked tab
            tab.classList.add('active');

            // Find target scan screen container
            const targetId = `scan-${tab.dataset.scanTarget}`;
            const targetScreen = document.getElementById(targetId);

            if (targetScreen) {
                // Get sibling screen containers and deactivate them
                const screens = document.querySelectorAll('.screen-image-container');
                screens.forEach(s => s.classList.remove('active'));

                // Activate selected screen container
                targetScreen.classList.add('active');

                // Retrigger laser animation to simulate a fresh scan
                if (laser) {
                    laser.classList.remove('active');
                    void laser.offsetWidth; // Trigger reflow to restart animation
                    laser.classList.add('active');
                }
            }
        });
    });


    // --- 4. INTERACTIVE APP SHOWCASE ---
    const showcaseTabs = document.querySelectorAll('.showcase-tab');
    const showcaseScreens = document.querySelectorAll('.showcase-screen');

    showcaseTabs.forEach(tab => {
        tab.addEventListener('click', () => {
            // Remove active class from tabs
            showcaseTabs.forEach(t => t.classList.remove('active'));
            // Add active class to clicked tab
            tab.classList.add('active');

            // Identify showcase screen targets
            const targetShowcase = tab.dataset.showcase;
            const targetScreen = document.getElementById(`showcase-${targetShowcase}`);

            if (targetScreen) {
                // Remove active class from all showcase screens
                showcaseScreens.forEach(screen => screen.classList.remove('active'));
                // Add active class to target screen
                targetScreen.classList.add('active');
            }
        });
    });


    // --- 5. BETA WAITLIST FORM SUBMISSION ---
    // SPREADSHEET INTEGRATION CONFIGURATION:
    // To route early access signups straight to your Google Sheet,
    // paste your deployed Google Apps Script Web App URL below:
    const GOOGLE_SHEETS_WEBAPP_URL = 'https://script.google.com/macros/s/AKfycbwjjduUOsuHXAWB5FUdkSQunUdliU-YVoNq6iA2UjPWq8eWXcZMaHISOpmlJwlxw7bLkA/exec';

    const betaForm = document.getElementById('beta-form');
    const successMessage = document.querySelector('.form-success-message');

    if (betaForm && successMessage) {
        betaForm.addEventListener('submit', (e) => {
            e.preventDefault();

            // Extract input values
            const name = document.getElementById('user-name').value;
            const email = document.getElementById('user-email').value;
            const goal = document.getElementById('user-goal').value;

            // Log waitlist signup for simulation verification
            console.log('Zivo Beta Request Received:', { name, email, goal });

            // Post to Google Sheet if Web App URL is configured
            if (GOOGLE_SHEETS_WEBAPP_URL && GOOGLE_SHEETS_WEBAPP_URL !== 'YOUR_GOOGLE_APPS_SCRIPT_WEBAPP_URL_HERE') {
                const params = new URLSearchParams();
                params.append('name', name);
                params.append('email', email);
                params.append('goal', goal);

                fetch(GOOGLE_SHEETS_WEBAPP_URL, {
                    method: 'POST',
                    mode: 'no-cors', // Prevents CORS pre-flight blocks on Google domains
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded'
                    },
                    body: params
                })
                .then(() => console.log('Waitlist submission forwarded to Google Sheets script successfully.'))
                .catch(err => console.error('Failed to forward waitlist submission to Google Sheets:', err));
            }

            // Animate transition between form and success message
            betaForm.style.transition = 'opacity 0.3s ease';
            betaForm.style.opacity = '0';

            setTimeout(() => {
                betaForm.style.display = 'none';
                successMessage.style.display = 'block';
            }, 300);
        });
    }


    // --- 6. SCROLL REVEAL ANIMATIONS (INTERSECTION OBSERVER) ---
    const revealElements = document.querySelectorAll(
        '.problem-card, .analyzer-content, .analyzer-visual, .eco-card, .comparison-col, .benefit-item, .waitlist-box'
    );

    const revealOnScroll = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('revealed');
                observer.unobserve(entry.target); // Stop observing once revealed
            }
        });
    }, {
        threshold: 0.15,
        rootMargin: '0px 0px -50px 0px'
    });

    revealElements.forEach(el => {
        // Prepare element for reveal animation via class
        el.classList.add('reveal-init');
        revealOnScroll.observe(el);
    });

    // --- 7. MINI BENTO WIDGETS INTERACTIVITY ---
    const hydrationVal = document.getElementById('hydration-val');
    const hydrationProgress = document.getElementById('hydration-progress');
    const hydrationPercentage = document.querySelector('.hydration-percentage');
    const hydrationButtons = document.querySelectorAll('.btn-hydration');

    if (hydrationVal && hydrationProgress && hydrationPercentage && hydrationButtons.length > 0) {
        let currentWater = 2500;
        const targetWater = 3130;

        hydrationButtons.forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation(); // Prevent card trigger
                const addAmount = parseInt(btn.dataset.add, 10);
                currentWater = Math.min(currentWater + addAmount, 5000);
                
                // Update text content
                hydrationVal.textContent = `${currentWater} ml`;
                
                // Calculate percentage
                const percentage = Math.min(Math.round((currentWater / targetWater) * 100), 100);
                hydrationPercentage.textContent = `${percentage}%`;
                
                // Update progress bar width
                hydrationProgress.style.width = `${percentage}%`;
                
                // Click animation
                btn.style.transform = 'scale(0.95)';
                setTimeout(() => btn.style.transform = 'none', 100);
            });
        });
    }

    // Gym log set list rows toggling
    const setRows = document.querySelectorAll('.set-row');
    setRows.forEach(row => {
        row.addEventListener('click', (e) => {
            e.stopPropagation();
            if (row.classList.contains('completed')) {
                row.classList.remove('completed');
                row.classList.add('active');
                const statusSpan = row.querySelector('.set-status-icon');
                if (statusSpan) {
                    statusSpan.remove();
                }
                const dotSpan = document.createElement('span');
                dotSpan.className = 'set-status-dot';
                row.appendChild(dotSpan);
            } else {
                row.classList.remove('active');
                row.classList.add('completed');
                const dotSpan = row.querySelector('.set-status-dot');
                if (dotSpan) {
                    dotSpan.remove();
                }
                const statusSpan = document.createElement('span');
                statusSpan.className = 'set-status-icon';
                statusSpan.textContent = '✓';
                row.appendChild(statusSpan);
            }
        });
    });

});
