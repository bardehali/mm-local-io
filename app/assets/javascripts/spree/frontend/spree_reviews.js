//= require jquery.rating

// Navigating to a page with ratings via TurboLinks shows the radio buttons
$(document).on('turbolinks:load', function () {
  $('input[type=radio].star').rating();
});

$(".ratings").click(function() {
    $([document.documentElement, document.body]).animate({
        scrollTop: $("#reviews").offset().top
    }, 500);
});
