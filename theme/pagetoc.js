// Un-active everything when you click it
Array.prototype.forEach.call(document.getElementsByClassName("pagetoc")[0].children, function(el) {
    el.addEventHandler("click", function() {
        Array.prototype.forEach.call(document.getElementsByClassName("pagetoc")[0].children, function(el) {
            el.classList.remove("active");
        });
        el.classList.add("active");
    });
});

var updateFunction = function() {

    var id;
    var elements = document.getElementsByClassName("header");
    Array.prototype.forEach.call(elements, function(el) {
        if (window.pageYOffset >= el.offsetTop) {
            id = el;
        }
    });

    Array.prototype.forEach.call(document.getElementsByClassName("pagetoc")[0].children, function(el) {
        el.classList.remove("active");
    });
    if (!id) return;
    Array.prototype.forEach.call(document.getElementsByClassName("pagetoc")[0].children, function(el) {
        if (id.href.localeCompare(el.href) == 0) {
            el.classList.add("active");
        }
    });
};

// Populate sidebar on load
window.addEventListener('load', function() {
    var pagetoc = document.getElementsByClassName("pagetoc")[0];
    var elements = document.getElementsByClassName("header");
    Array.prototype.forEach.call(elements, function (el) {
        var link = document.createElement("a");
        link.appendChild(document.createTextNode(el.text));
        link.href = el.href;
        link.classList.add("pagetoc-" + el.parentElement.tagName);
        pagetoc.appendChild(link);
      });
    updateFunction.call();

    // Adjust the right / forward-nav bar to not overlap with pagetoc
    const next_banner = document.getElementsByClassName("nav-chapters next")[0];
    next_banner.style.top = pagetoc.getBoundingClientRect().bottom + "px";
});



// Handle active elements on scroll
window.addEventListener("scroll", updateFunction);
