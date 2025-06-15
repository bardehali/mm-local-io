var PRODUCT_ADDED_MODAL_SELECTOR = '.product-added-modal'

Spree.hasProductAddedModal = function() {
  var $modal = $(PRODUCT_ADDED_MODAL_SELECTOR)
  return ( typeof($modal) != 'undefined' && $modal.length > 0 && typeof($modal.modal) == 'function' )
}

Spree.showProductAddedModal = function(product, variant) {
  var nameSelector = '.product-added-modal-product-details-name'
  var priceSelector = '.product-added-modal-product-details-price'
  var imageSelector = '.product-added-modal-product-image-container-image'
  var modalNoImageClass = 'product-added-modal--no-image'

  var price = variant.display_price
  var images = variant && variant.images.length > 0 ? variant.images : product.images
  var name = product.name
  var leadImage = images.length === 0 ? null : images[0]

  if (Spree.hasProductAddedModal() )
  {
    var $modal = $(PRODUCT_ADDED_MODAL_SELECTOR)
    $modal.find(nameSelector).text(name)
    $modal.find(priceSelector).html(price)

    if (leadImage !== null) {
      $modal
        .removeClass(modalNoImageClass)
        .find(imageSelector)
        .attr('src', leadImage.url_product)
        .attr('alt', leadImage.alt || name)
    } else {
      $modal.addClass(modalNoImageClass)
    }

    $modal.modal()
  }
}

Spree.hideProductAddedModal = function() {
  var $modal = $(PRODUCT_ADDED_MODAL_SELECTOR)

  if (Spree.hasProductAddedModal() ) {
    $modal.modal('hide')
  }
}
