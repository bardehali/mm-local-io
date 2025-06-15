//= require spree/frontend/coupon_manager

Spree.ready(function ($) {
  var formUpdateCartQuery = $('form.update-cart-form')

  formUpdateCartQuery.each(function() {
    var formUpdateCart = $(this);
    var clearInvalidCouponField = function() {
      var couponCodeField = formUpdateCart.find('#order_coupon_code');
      var couponStatus = formUpdateCart.find('#coupon_status');
      if (!!couponCodeField.val() && couponStatus.hasClass('alert-error')) {
        couponCodeField.val('')
      }
    }

    formUpdateCart.find('a.delete').show().one('click', function () {
      $(this).parents('.shopping-cart-item').first().find('input.shopping-cart-item-quantity-input').val(0)
      clearInvalidCouponField()
      formUpdateCart.submit()
      return false
    })
    formUpdateCart.find('input.shopping-cart-item-quantity-input').on('keyup', function(e) {
      var itemId = $(this).attr('data-id')
      var value = $(this).val()
      var newValue = isNaN(value) || value === '' ? value : parseInt(value, 10)
      var targetInputs = formUpdateCart.find("input.shopping-cart-item-quantity-input[data-id='" + itemId + "']")
      $(targetInputs).val(newValue)
    })
    formUpdateCart.find('input.shopping-cart-item-quantity-input').on('change', function(e) {
      clearInvalidCouponField()
      formUpdateCart.submit()
    })
    formUpdateCart.find('button.shopping-cart-item-quantity-decrease-btn').off('click').on('click', function() {
      var itemId = $(this).attr('data-id')
      var input = $("input[data-id='" + itemId + "']")
      var inputValue = parseInt($(input).val(), 10)

      if (inputValue > 1) {
        $(input).val(inputValue - 1)
        formUpdateCart.submit()
      }
    })
    formUpdateCart.find('button.shopping-cart-item-quantity-increase-btn').off('click').on('click', function() {
      var itemId = $(this).attr('data-id')
      var input = $("input[data-id='" + itemId + "']")
      var inputValue = parseInt($(input).val(), 10)

      $(input).val(inputValue + 1)
      clearInvalidCouponField()
      formUpdateCart.submit()
    })
    formUpdateCart.find('button#shopping-cart-coupon-code-button').off('click').on('click', function(event) {
      var couponCodeField = formUpdateCart.find('#order_coupon_code');

      if (!$.trim(couponCodeField.val()).length) {
        event.preventDefault()
        return false
      }
    })

    formUpdateCart.find('button#shopping-cart-remove-coupon-code-button').off('click').on('click', function(event) {
      var input = {
        appliedCouponCodeField: formUpdateCart.find('#order_applied_coupon_code'),
        couponCodeField: formUpdateCart.find('#order_coupon_code'),
        couponStatus: formUpdateCart.find('#coupon_status'),
        couponButton: formUpdateCart.find('#shopping-cart-coupon-code-button'),
        removeCouponButton: formUpdateCart.find('#shopping-cart-remove-coupon-code-button')
      }

      if (new CouponManager(input).removeCoupon()) {
        return true
      } else {
        event.preventDefault()
        return false
      }
    });

    formUpdateCart.submit(function (event) {
      var input = {
        couponCodeField: formUpdateCart.find('#order_coupon_code'),
        couponStatus: formUpdateCart.find('#coupon_status'),
        couponButton: formUpdateCart.find('#shopping-cart-coupon-code-button')
      }
      var updateButton = formUpdateCart.find('#update-button')
      updateButton.attr('disabled', true)
      if ($.trim(input.couponCodeField.val()).length > 0) {
        // eslint-disable-next-line no-undef
        if (new CouponManager(input).applyCoupon()) {
          this.submit()
          return true
        } else {
          updateButton.attr('disabled', false)
          event.preventDefault()
          return false
        }
      }
    })
  } ); // forEach

  if (!Spree.cartFetched) Spree.fetchCart()
})

Spree.fetchCart = function () {
  return $.ajax({
    url: Spree.pathFor('cart_link')
  }).done(function (data) {
    Spree.cartFetched = true
    return $('#link-to-cart').html(data)
  })
}

Spree.ensureCart = function (successCallback) {
  if (SpreeAPI.orderToken) {
    successCallback()
  } else {
    fetch(Spree.routes.ensure_cart, {
      method: 'POST',
      credentials: 'same-origin'
    }).then(function (response) {
      switch (response.status) {
        case 200:
          response.json().then(function (json) {
            SpreeAPI.orderToken = json.token
            successCallback()
          })
          break
      }
    })
  }
}
