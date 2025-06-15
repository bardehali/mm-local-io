var getQueryString = window.location.search
var urlParams = new URLSearchParams(getQueryString)
var variantIdFromUrl = urlParams.get('variant')

this.initializeQueryParamsCheck = function () {
  if (urlParams.has('variant')) verifyVariantIdMatch()
}

function verifyVariantIdMatch() {
  this.variants.forEach(function(variant) {
    if (parseInt(variant.id) === parseInt(variantIdFromUrl)) this.urlQueryMatchFound = true
  })
}

this.setSelectedVariantFromUrl = function () {
  this.selectedOptions = []

  this.getVariantOptionsById(variantIdFromUrl)
  this.sortArrayByOptionTypeIndex(this.selectedOptions)
  this.clickListOptions(this.selectedOptions)
}

this.getVariantOptionsById = function(variantIdFromUrl) {
  this.variants.forEach(function(variant) {
    if (parseInt(variant.id) === parseInt(variantIdFromUrl)) this.sortOptionValues(variant.option_values)
  })
}

this.sortOptionValues = function(optVals) {
  optVals.forEach(buildArray)
}

function buildArray(item) {
  var container = document.querySelector('ul#product-variants')
  var target = container.querySelectorAll('.product-variants-variant-values-radio')

  target.forEach(function(inputTag) {
    if (parseInt(inputTag.value) === item.id && inputTag.dataset.presentation === item.presentation) {
      this.selectedOptions.push(inputTag)
    }
  })
}

this.sortArrayByOptionTypeIndex = function (arrayOfOptions) {
  arrayOfOptions.sort(function (a, b) {
    return a.dataset.optionTypeIndex > b.dataset.optionTypeIndex ? 1 : -1;
  })
}

this.clickListOptions = function(list) {
  list.forEach(function (item) {
    item.checked = true
    var $optionListItem = $(item)
    this.applyCheckedOptionValue($optionListItem)
  })
}

this.initializeColorVarianTooltip = function() {
  var colorVariants = $('.color-select-label[data-toggle="tooltip"]')
  colorVariants.tooltip({
    placement: 'bottom'
  })
}
