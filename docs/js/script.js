/* =====================================
        ROUTELK JAVASCRIPT
===================================== */



// =====================================
// NAVBAR BACKGROUND ON SCROLL
// =====================================


const navbar = document.querySelector(".navbar");


window.addEventListener("scroll", () => {


    if (window.scrollY > 50) {


        navbar.style.background =
            "rgba(7,17,31,0.92)";


        navbar.style.boxShadow =
            "0 10px 30px rgba(0,0,0,.3)";


    }

    else {


        navbar.style.background =
            "rgba(255,255,255,0.05)";


        navbar.style.boxShadow =
            "none";


    }


});






// =====================================
// SMOOTH SCROLL
// =====================================



document.querySelectorAll("a[href^='#']")
    .forEach(link => {


        link.addEventListener("click", function (e) {


            const section =
                document.querySelector(
                    this.getAttribute("href")
                );


            if (section) {


                e.preventDefault();


                section.scrollIntoView({

                    behavior: "smooth"

                });


            }


        });


    });







// =====================================
// ACTIVE NAVBAR SECTION
// =====================================


const sections =
    document.querySelectorAll("section");


const navLinks =
    document.querySelectorAll(".nav-links a");



window.addEventListener("scroll", () => {


    let current = "";


    sections.forEach(section => {


        const sectionTop =
            section.offsetTop - 150;



        if (scrollY >= sectionTop) {


            current =
                section.getAttribute("id");


        }


    });



    navLinks.forEach(link => {


        link.style.color = "#d8e2f0";


        if (link.getAttribute("href")
            ==
            "#" + current) {


            link.style.color =
                "#f8c63d";


        }



    });


});







// =====================================
// CARD REVEAL ANIMATION
// =====================================



const revealElements =
    document.querySelectorAll(
        ".card, .architecture div, .hardware div, .test-card, .timeline div, .flow-box, .role-card, .tech-category-card, .team-card"
    );



const revealObserver =
    new IntersectionObserver(
        (entries) => {


            entries.forEach(entry => {


                if (entry.isIntersecting) {


                    entry.target.style.opacity = "1";


                    entry.target.style.transform =
                        "translateY(0)";


                }


            });


        },
        {

            threshold: 0.15

        });





revealElements.forEach(element => {


    element.style.opacity = "0";


    element.style.transform =
        "translateY(40px)";


    element.style.transition =
        "all .8s ease";


    revealObserver.observe(element);


});








// =====================================
// BUTTON INTERACTION
// =====================================



const buttons =
    document.querySelectorAll(
        "button"
    );



buttons.forEach(button => {


    button.addEventListener(
        "mouseenter",
        () => {


            button.style.transform =
                "scale(1.08)";


        });



    button.addEventListener(
        "mouseleave",
        () => {


            button.style.transform =
                "scale(1)";


        });


});








// =====================================
// MOUSE GLOW EFFECT
// =====================================



document.addEventListener(
    "mousemove",
    (e) => {


        let glow =
            document.querySelector(
                ".mouse-glow"
            );



        if (!glow) {


            glow =
                document.createElement(
                    "div"
                );



            glow.className =
                "mouse-glow";



            document.body.appendChild(glow);


        }



        glow.style.left =
            e.clientX + "px";


        glow.style.top =
            e.clientY + "px";


    });







// =====================================
// FLOATING PARTICLES
// =====================================



const particleContainer =
    document.querySelector(".particles");



if (particleContainer) {



    for (let i = 0; i < 50; i++) {



        let particle =
            document.createElement("span");



        particle.className =
            "particle";



        particle.style.left =
            Math.random() * 100 + "%";



        particle.style.top =
            Math.random() * 100 + "%";



        particle.style.animationDelay =
            Math.random() * 6 + "s";



        particleContainer.appendChild(
            particle
        );



    }



}








// =====================================
// TESTING PROGRESS ANIMATION
// =====================================



const progressBars =
    document.querySelectorAll(
        ".progress span"
    );



const progressObserver =
    new IntersectionObserver(
        (entries) => {


            entries.forEach(entry => {


                if (entry.isIntersecting) {


                    const width =
                        entry.target.style.width;


                    entry.target.style.width = "0";



                    setTimeout(() => {


                        entry.target.style.width =
                            width;


                    }, 300);


                }



            });


        });



progressBars.forEach(bar => {


    progressObserver.observe(bar);


});







// =====================================
// COUNTER ANIMATION
// =====================================



function animateCounter(element, target) {



    let value = 0;



    let speed =
        target / 100;



    const timer =
        setInterval(() => {


            value += speed;



            if (value >= target) {


                value = target;


                clearInterval(timer);


            }



            element.innerText =
                Math.floor(value);



        }, 20);



}






// =====================================
// LIVE BUS SIMULATION
// =====================================



let busNumber = 1;



setInterval(() => {


    busNumber++;



    if (busNumber > 5) {

        busNumber = 1;

    }


}, 3000);








// =====================================
// PAGE LOAD EFFECT
// =====================================



window.addEventListener(
    "load",
    () => {


        document.body.style.opacity = "1";


    });







// =====================================
// MOBILE MENU
// =====================================



const nav =
    document.querySelector(
        ".nav-links"
    );



const navButton =
    document.querySelector(
        ".nav-btn"
    );



if (window.innerWidth < 900) {


    navButton.addEventListener(
        "click",
        () => {


            nav.style.display =
                nav.style.display === "flex"
                    ?
                    "none"
                    :
                    "flex";



        });


}


// =====================================
// IMAGE LIGHTBOX MODAL
// =====================================
document.addEventListener("DOMContentLoaded", () => {
    const architectureCards = document.querySelectorAll(".architecture-card");
    const imageModal = document.getElementById("imageModal");
    const modalImg = document.getElementById("modalImg");
    const modalCaption = document.getElementById("modalCaption");

    if (architectureCards.length > 0 && imageModal && modalImg) {
        architectureCards.forEach(card => {
            card.addEventListener("click", () => {
                const img = card.querySelector("img");
                const heading = card.querySelector("h2");
                if (img) {
                    imageModal.classList.add("active");
                    modalImg.src = img.src;
                    modalImg.alt = img.alt;
                    if (heading) {
                        modalCaption.textContent = heading.textContent;
                    } else {
                        modalCaption.textContent = img.alt || "";
                    }
                }
            });
        });

        // Close modal when clicking on it (backdrop or close button)
        imageModal.addEventListener("click", (e) => {
            if (e.target === imageModal || e.target.classList.contains("image-modal-close")) {
                imageModal.classList.remove("active");
            }
        });

        // Close on Escape key press
        document.addEventListener("keydown", (e) => {
            if (e.key === "Escape" && imageModal.classList.contains("active")) {
                imageModal.classList.remove("active");
            }
        });
    }

    // Hero buttons scroll actions
    const exploreBtn = document.getElementById("btn-explore");
    const archBtn = document.getElementById("btn-architecture");

    if (exploreBtn) {
        exploreBtn.addEventListener("click", () => {
            const problemSection = document.getElementById("problem");
            if (problemSection) {
                problemSection.scrollIntoView({ behavior: "smooth" });
            }
        });
    }

    if (archBtn) {
        archBtn.addEventListener("click", () => {
            const archSection = document.getElementById("architecture");
            if (archSection) {
                archSection.scrollIntoView({ behavior: "smooth" });
            }
        });
    }

    // Get Started button scroll action
    const getStartedBtn = document.getElementById("btn-get-started");
    if (getStartedBtn) {
        getStartedBtn.addEventListener("click", () => {
            const solutionSection = document.getElementById("solution");
            if (solutionSection) {
                solutionSection.scrollIntoView({ behavior: "smooth" });
            }
        });
    }

    // Scroll to Top action
    const scrollToTopBtn = document.getElementById("scrollToTop");
    if (scrollToTopBtn) {
        window.addEventListener("scroll", () => {
            if (window.scrollY > 300) {
                scrollToTopBtn.classList.add("show");
            } else {
                scrollToTopBtn.classList.remove("show");
            }
        });

        scrollToTopBtn.addEventListener("click", () => {
            window.scrollTo({
                top: 0,
                behavior: "smooth"
            });
        });
    }
});