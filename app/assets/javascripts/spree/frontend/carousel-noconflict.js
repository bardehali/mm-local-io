// $.fn.carousel already occupied by legacy plugin. Need to use a different name for Bootstrap 4's carousel.
// Save the original plugin to a different variable
var carouselBootstrap4 = $.fn.carousel.noConflict();

// Add the Bootstrap 4 carousel plugin under a different name
$.fn.carouselBootstrap4 = carouselBootstrap4;

// // carousel-noconflict.js
// (function($) {
//   // Completely redefine carousel initialization
//   $.fn.carouselBootstrap4 = function(options) {
//     // If no carousel method exists, create a fallback
//     if (!$.fn.carousel) {
//       console.error('Bootstrap carousel not found');
//       return this;
//     }
//
//     return this.each(function() {
//       var $this = $(this);
//
//       // Remove any existing carousel initialization
//       $this.off('slide.bs.carousel')
//            .off('slid.bs.carousel');
//
//       // Merge options with defaults
//       var carouselOptions = $.extend({
//         interval: false,
//         pause: 'hover',
//         ride: false
//       }, options);
//
//       try {
//         // Initialize carousel using standard Bootstrap method
//         $this.carousel(carouselOptions);
//
//         console.log('Carousel initialized:', $this.attr('id') || 'unnamed carousel');
//       } catch (error) {
//         console.error('Carousel initialization error:', error);
//       }
//     });
//   };
//
//   // Spree-specific initialization
//   Spree.ready(function($) {
//     console.log('Spree comprehensive carousel initialization');
//
//     // Multiple initialization strategies
//     $('.carousel').each(function() {
//       var $carousel = $(this);
//
//       // Check for Spree-specific data attributes
//       var interval = $carousel.data('interval');
//       var carouselOptions = interval !== undefined
//         ? { interval: interval }
//         : {};
//
//       try {
//         // Force initialization
//         $carousel.carouselBootstrap4(carouselOptions);
//       } catch (error) {
//         console.error('Carousel initialization failed:', error);
//       }
//     });
//   });
//
//   // Turbolinks compatibility
//   $(document).on('turbolinks:load', function() {
//     console.log('Turbolinks reload: Force carousel reinitialization');
//     $('.carousel').carouselBootstrap4();
//   });
//
//   // Global fallback - override any existing calls
//   window.carouselBootstrap4 = $.fn.carouselBootstrap4;
// })(jQuery);
