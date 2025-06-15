var productImageArrayIndex = 1;

function addMoreProductImageRow() {
  var html = $("#new_product_image_row").html();
  $(".product-image-row").parent().append("<tr id='new_product_image_row_" + productImageArrayIndex + "'>" + html + "</tr>");
  $("#new_product_image_row_" + productImageArrayIndex +" .paste-target").on("click", selectedPasteTarget);
  productImageArrayIndex++;
}

function addMoreProductPropertyRow() {
  var firstRow = $("#spree_new_product_property");
  var html = firstRow.html().replace(/\[0\]/g, '[' + firstRow.parent().children().size() +']' );
  var newRow = firstRow.parent().append("<tr class='product_property fields' data-hook='product_property'>" + html + '</tr>');
}

function removeOptionMappingRow(el) {

}

var currenyPriceArrayIndex = 1;
function updateCurrencyPriceField() {
  if ($(this).val() == '') {
  } else {
    addCurrencyPriceField();
    refreshCurrencySelectList();
    initCurrencyPriceField();
  }
}

function addCurrencyPriceField() {
  var html = $("#new_currency_price_wrapper").html();
  $("#curreny_prices_list").append("<div class='col-6 mb-2' id='new_currency_price_wrapper_" + currenyPriceArrayIndex + "'>" + html + "</div>");
  currenyPriceArrayIndex++;
  $("#curreny_prices_list > div:last-child input[type='text']").focus();
}

function refreshCurrencySelectList() {
  var currencyTypeList = $("#curreny_prices_list *[data-type='currency']");
  if (currencyTypeList.length > 1) {
    var existingValues = [];
    currencyTypeList.each(function(index){
      if($(this).val() != ""){ existingValues.push( $(this).val() ); }
    });
    $("#curreny_prices_list select[data-type='currency']").each(function(index){
      var selectField = $(this);
      var siblingAmountField =  $( selectField.siblings("input[type='text']")[0] );
      if (siblingAmountField != null && $(siblingAmountField).val() == '') {
        selectField.children().each(function(cindex){
          if (existingValues.includes( $(this).val() ) ) {
            $(this).remove();
          }
        });
      }
    });
  }
}

function taxonsChanged() {
  fetchRelatedOptionoTypes( $(this) );
}

function optionTypesChanged() {
  loadOptionTypes( this );
}

/* Change of option types triggers re-render of selectors. */
function loadOptionTypes(el) {
  if  ($('#product_option_type_ids').length == 0) { return false; }
  var url = '/option_types/load.js?token=' + Spree.api_key;
  url += "&product_id=" + $("#product_id").val();
  var option_type_ids = $('#product_option_type_ids').val().split(',');
  for (var i = 0; i < option_type_ids.length; i++) {
    url += "&option_type_ids[]=" + option_type_ids[i];
    $("#option_type_body_" + option_type_ids[i] + " input:checked").each( function(index, input) {
      url += "&selected_option_value_ids[]=" + $(input).val();
    });
  }
  Spree.ajax({
    url: url,
    success: function(result) { }
  });
}

function fetchRelatedOptionoTypes(el) {
  var value = $(el).val();
  if (value == '') { value = 1; }
  var label = (el.tagName == 'SELECT') ? $(el).children('option:selected').text() : '';
  var url = '/related_option_types/taxon/' + value + '.js?label=' + label + '&token=' + Spree.api_key + "&product_id=" + $('#product_id').val();
  var checkboxes = $(".color-wrapper input[type='checkbox']");
  for (var i = 0; i < checkboxes.length; i++) {
    var checkbox = checkboxes[i];
    if ( $(checkbox).prop('checked') == true) { url += "&other_option_value_ids[]=" + $(checkbox).val(); }
  }
  Spree.ajax({
    url: url,
    success: function(result) { }
  });
}

function showAllRows() {
  $( $(this).data('table-to-collapse') + " tr.row-collapsable").removeClass("row-collapsable");
  $(this).hide();
}

/****************************
 * Initiators
*/
function initCurrencyPriceField() {
  $("input[name='product[price_attributes][][amount]']").on('change', updateCurrencyPriceField);
}

function initCategorySelector() {
  $('#product_category').on('change', taxonsChanged);
  $('#product_taxon_ids').on('change', taxonsChanged);
  $('#product_option_type_ids').on('change', optionTypesChanged);
}

picker = {};

function loadColorPicker() {
  var p = $('.color-picker-palette')[0]; // put color picker panel in the second `<p>` element
  if (p == undefined)
    return;

  picker = new CP($('#color_picker_preview_color')[0], false, p);

  picker.on("change", function(color) {
    this.source.value = '#' + color;

    $('.color-picker-preview .m-auto').empty();
    colorname = 'New Color';
    colorid = '';
    colorvalue = '#' + color;
    el = makeColorBox(colorid, colorvalue, colorname);
    $('#color_box_extra_value').val(colorvalue);

    $('.color-picker-preview .m-auto').append(el);
    $('.color-picker-preview .m-auto .color-box').addClass('readonly');
  });

  return picker;
}

String.prototype.replaceAll = function(search, replacement) {
  var target = this;
  return target.replace(new RegExp(search, 'g'), replacement);
};

const colorbox_template1 = '<div class="color-wrapper"><input type="checkbox" data="colorid" name="colorname" value="colorvalue"/><label class="color-box option-value-btn" onclick="toggleSelection(this)" style="border-color: black;" data="colorid" data-name="colorname" data-value="colorvalue"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" style="isolation:isolate" viewBox="4 6 40 40" width="40pt" height="40pt" class="color-value-button"><defs><clipPath id="_clipPath_tb3pgmzt71gZgjRUMFz7kla7XsGZguKQ"><rect width="50" height="50"></rect></clipPath></defs><g clip-path="url(#_clipPath_tb3pgmzt71gZgjRUMFz7kla7XsGZguKQ)"><mask id="_mask_oCFp9qrrrQeffIoCHuWrFndlIZ6tpd83"></mask><circle vector-effect="non-scaling-stroke" cx="25" cy="25" r="25" fill="none" mask="url(#_mask_oCFp9qrrrQeffIoCHuWrFndlIZ6tpd83)" stroke-width="6" stroke="color1" stroke-linejoin="miter" stroke-linecap="square" stroke-miterlimit="3"></circle><circle vector-effect="non-scaling-stroke" cx="25" cy="25" r="25" fill="none"></circle><path d=" M 35.432 11.739 C 32.56 9.476 28.937 8.125 25 8.125 C 15.686 8.125 8.125 15.686 8.125 25 C 8.125 28.937 9.476 32.56 11.739 35.432 L 35.432 11.739 Z  M 38.261 14.568 C 40.524 17.44 41.875 21.063 41.875 25 C 41.875 34.314 34.314 41.875 25 41.875 C 21.063 41.875 17.44 40.524 14.568 38.261 L 38.261 14.568 Z " fill-rule="evenodd" fill="color1"></path><circle vector-effect="non-scaling-stroke" cx="24.999999999999996" cy="24.999999999999996" r="16.875000000000007" fill="color1"></circle></g></svg></label></div>';
const colorbox_template2 = '<div class="color-wrapper"><input type="checkbox" data="colorid" name="colorname" value="colorvalue"/><label class="color-box option-value-btn" onclick="toggleSelection(this)" style="border-color: black;" data="colorid" data-name="colorname" data-value="colorvalue"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" style="isolation:isolate" viewBox="0 0 50 50" width="50pt" height="50pt"><defs><clipPath id="_clipPath_JuHM8qzruj2aKf5MW2NorbnVxhGKkLBN"><rect width="50" height="50"></rect></clipPath></defs><g clip-path="url(#_clipPath_JuHM8qzruj2aKf5MW2NorbnVxhGKkLBN)"><mask id="_mask_9uwPSRnBTIHwKN84BkS867cKeriONcUn"></mask><circle vector-effect="non-scaling-stroke" cx="20" cy="20" r="20" fill="none" mask="url(#_mask_9uwPSRnBTIHwKN84BkS867cKeriONcUn)" stroke-width="4" stroke="color1" stroke-linejoin="miter" stroke-linecap="square" stroke-miterlimit="3"></circle><circle vector-effect="non-scaling-stroke" cx="25" cy="25" r="25" fill="none"></circle><path d=" M 35.432 11.739 C 32.56 9.476 28.937 8.125 25 8.125 C 15.686 8.125 8.125 15.686 8.125 25 C 8.125 28.937 9.476 32.56 11.739 35.432 L 35.432 11.739 Z  M 38.261 14.568 C 40.524 17.44 41.875 21.063 41.875 25 C 41.875 34.314 34.314 41.875 25 41.875 C 21.063 41.875 17.44 40.524 14.568 38.261 L 38.261 14.568 Z " fill-rule="evenodd" fill="color2"></path><path d=" M 38.261 14.568 C 40.524 17.44 41.875 21.063 41.875 25 C 41.875 34.314 34.314 41.875 25 41.875 C 21.063 41.875 17.44 40.524 14.568 38.261 L 38.261 14.568 L 38.261 14.568 Z " fill-rule="evenodd" fill="color1"></path></g></svg></label></div>';
const t_colorbox_template1 = '<div class="variant-one-box"><div class="color-wrapper"><div class="color-box option-value-btn" onclick="toggleSelection(this)" style="border-color: black;" data="colorid" data-name="colorname" data-value="colorvalue"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" style="isolation:isolate" viewBox="4 6 40 40" width="40pt" height="40pt" class="color-value-button"><defs><clipPath id="_clipPath_tb3pgmzt71gZgjRUMFz7kla7XsGZguKQ"><rect width="50" height="50"></rect></clipPath></defs><g clip-path="url(#_clipPath_tb3pgmzt71gZgjRUMFz7kla7XsGZguKQ)"><mask id="_mask_oCFp9qrrrQeffIoCHuWrFndlIZ6tpd83"></mask><circle vector-effect="non-scaling-stroke" cx="25" cy="25" r="25" fill="none" mask="url(#_mask_oCFp9qrrrQeffIoCHuWrFndlIZ6tpd83)" stroke-width="6" stroke="color1" stroke-linejoin="miter" stroke-linecap="square" stroke-miterlimit="3"></circle><circle vector-effect="non-scaling-stroke" cx="25" cy="25" r="25" fill="none"></circle><path d=" M 35.432 11.739 C 32.56 9.476 28.937 8.125 25 8.125 C 15.686 8.125 8.125 15.686 8.125 25 C 8.125 28.937 9.476 32.56 11.739 35.432 L 35.432 11.739 Z  M 38.261 14.568 C 40.524 17.44 41.875 21.063 41.875 25 C 41.875 34.314 34.314 41.875 25 41.875 C 21.063 41.875 17.44 40.524 14.568 38.261 L 38.261 14.568 Z " fill-rule="evenodd" fill="color1"></path><circle vector-effect="non-scaling-stroke" cx="24.999999999999996" cy="24.999999999999996" r="16.875000000000007" fill="color1"></circle></g></svg></div>	</div><div class="variant-description box-shadow"><div class="variant-heading"><span>varname</span></div><div class="variant-body"><input class="variant-name" readonly="readonly" value="colorname"></div><div class="variant-footer"><div class="cover"></div></div></div></div>';
const t_colorbox_template2 = '<div class="variant-one-box"><div class="color-wrapper"><div class="color-box option-value-btn" onclick="toggleSelection(this)" style="border-color: black;" data="colorid" data-name="colorname" data-value="colorvalue"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" style="isolation:isolate" viewBox="0 0 40 40" width="50pt" height="50pt"><defs><clipPath id="_clipPath_JuHM8qzruj2aKf5MW2NorbnVxhGKkLBN"><rect width="50" height="50"></rect></clipPath></defs><g clip-path="url(#_clipPath_JuHM8qzruj2aKf5MW2NorbnVxhGKkLBN)"><mask id="_mask_9uwPSRnBTIHwKN84BkS867cKeriONcUn"></mask><circle vector-effect="non-scaling-stroke" cx="20" cy="20" r="20" fill="none" mask="url(#_mask_9uwPSRnBTIHwKN84BkS867cKeriONcUn)" stroke-width="4" stroke="color1" stroke-linejoin="miter" stroke-linecap="square" stroke-miterlimit="3"></circle><circle vector-effect="non-scaling-stroke" cx="25" cy="25" r="25" fill="none"></circle><path d=" M 35.432 11.739 C 32.56 9.476 28.937 8.125 25 8.125 C 15.686 8.125 8.125 15.686 8.125 25 C 8.125 28.937 9.476 32.56 11.739 35.432 L 35.432 11.739 Z  M 38.261 14.568 C 40.524 17.44 41.875 21.063 41.875 25 C 41.875 34.314 34.314 41.875 25 41.875 C 21.063 41.875 17.44 40.524 14.568 38.261 L 38.261 14.568 Z " fill-rule="evenodd" fill="color2"></path><path d=" M 38.261 14.568 C 40.524 17.44 41.875 21.063 41.875 25 C 41.875 34.314 34.314 41.875 25 41.875 C 21.063 41.875 17.44 40.524 14.568 38.261 L 38.261 14.568 L 38.261 14.568 Z " fill-rule="evenodd" fill="color1"></path></g></svg></div></div><div class="variant-description box-shadow"><div class="variant-heading"><span>varname</span></div><div class="variant-body"><input class="variant-name" readonly="readonly" value="colorname"></div><div class="variant-footer"><div class="cover"></div></div></div></div>';

function makeColorBox(colorid, colorvalue, colorname) {
  colors = colorvalue.split(',');
  color1 = colors[0];
  color2 = colors.length > 1 ? colors[1] : ''
  if (color2 == '') {
    el = colorbox_template1;
    el = el.replaceAll('color1', color1);
  } else {
    el = colorbox_template2;
    el = el.replaceAll('color1', color1);
    el = el.replaceAll('color2', color2);
  }
  el = el.replaceAll('colorid', colorid);
  el = el.replaceAll('colorvalue', colorvalue);
  el = el.replaceAll('colorname', colorname);
  return el;
}

function makeTippedColorBox(colorid, colorvalue, colorname) {
  colors = colorvalue.split(',');
  color1 = colors[0];
  color2 = colors.length > 1 ? colors[1] : ''
  if (color2 == '') {
    el = t_colorbox_template1;
    el = el.replaceAll('color1', color1);
  } else {
    el = t_colorbox_template2;
    el = el.replaceAll('color1', color1);
    el = el.replaceAll('color2', color2);
  }
  el = el.replaceAll('colorid', colorid);
  el = el.replaceAll('colorvalue', colorvalue);
  el = el.replaceAll('colorname', colorname);
  el = el.replaceAll('variantname', colorname);
  return el;
}


function removeRow(obj){
  $(obj).parentsUntil('tbody').find("td input[type='checkbox']").prop('checked', false);
  $(obj).parentsUntil('tbody').remove();
};

function checkColumn(obj) {
  idx = $(obj).attr('data-idx');
  if ($(obj).find('.selected').length == 0) {
    $('.sizes-box tbody tr td:nth-child(' + idx + ')').find('input').prop('checked', false);
  } else {
    $('.sizes-box tbody tr td:nth-child(' + idx + ')').find('input').prop('checked', true);
  }
}

function checkCell(obj) {
  p = $(obj).find('input').prop('checked');
  $(obj).find('input').prop('checked', !p);
}

function alternateOneValueCheckbox( el ) {
  var oneValueInput
  var nonOneValueChecked = 0
  var wrapper = (el.tagName == 'LABEL' || el.tagName == 'INPUT') ? $(el).parent() : $(el)
  var q = '#' + wrapper.parent().prop('id') + ' input'
  $(q).each(function(){
    if ($(this).parent().hasClass('one-value-row') || $(this).parent().hasClass('one-value-box') ) { oneValueInput = $(this) }
    else if ( $(this).prop('checked') ) { nonOneValueChecked += 1 }
  })
  if (oneValueInput) {
    oneValueInput.prop('checked', (nonOneValueChecked > 0) ? '' : true )
  }
}

function clickedSelectionButton() {
  toggleSelection(this);
  if ($(this).prop('for') != undefined) {
    $("input[name='" + $(this).prop('for') + "']").prop('checked', $(this).hasClass('selected') );
  }
  if ( $('#product_option_type_ids') != undefined &&  $('#product_option_type_ids').val() != '') {
    alternateOneValueCheckbox( this )
    loadOptionTypes( this );
  }
}

function toggleSelection(obj){
  if (!$(obj).hasClass('selectable')) {
    $(obj).toggleClass('selected');
  }
}

/* Color palette and picker */
function paletteColor_clicked() {
  if ($(this).hasClass('selected')) {
    $(this).toggleClass('selected');
    for( var i = 0; i < selections.length; i++){
      if ( selections[i].colorid == $(this).attr('data')) {
        selections.splice(i, 1);
      }
    }
    drawPreview();
  } else if (selections.length < 2) {
    $(this).toggleClass('selected');
    selections.push({
      colorname: $(this).attr('data-name'),
      colorid: $(this).attr('data'),
      colorvalue: $(this).attr('data-value'),
      variantname: $(this).attr('data-value')
    });
    drawPreview();
  }
}


function drawPreview() {
  if (selections.length == 0) return;
  var colorname = '';
  var colorvalue = '';
  var el = '';

  $('.color-palette-preview .m-auto').empty();
  if (selections.length > 1) {
    colorname = selections[0].colorname + ' / ' + selections[1].colorname;
    colorid = '';                         // ------------------> we need to get this value from server (new color combination id or existing id)
    colorvalue = selections[0].colorvalue + ',' + selections[1].colorvalue;
    el = makeColorBox(colorid, colorvalue, colorname);
  } else {
    colorname = selections[0].colorname;
    colorid = selections[0].colorid;
    colorvalue = selections[0].colorvalue;
    el = makeColorBox(colorid, colorvalue, colorname);
  }
  $('#color_picker_preview_presentation').prop('value', colorname);
  $('#color_picker_preview_extra_value').prop('value', colorvalue);
  $('.color-palette-preview .m-auto').append(el);
  $('.color-palette-preview .m-auto .color-box').addClass('readonly');
}

function initAutoFileUpload() {
  $("input.auto-upload-file").on('change', function(){
    $(this).siblings("button[type='submit']").click();
  } );
}

function initRestrictPriceOnlyInput() {
  $("input[data-type='price-only']").on('change', validatePriceOnlyInput);
  $("input[data-type='price-only']").on('keydown', restrictPriceOnlyInput);
}

var PRICE_ONLY_REGEXP = new RegExp(/^\d+\.?\d*$/);

function validatePriceOnlyInput(e) {
  var value = $(this).val().trim();
  $(this).parent().addClass('withError');
  return isValidPrice(value);
}

function restrictPriceOnlyInput(e) {
  if (e.shiftKey === true ) {
    if (e.which == 9) {
      return true;
    }
    return false;
  }
  if (e.which == 190) { return true; }
  if (e.which > 57) { return false; }
  if (e.which == 32) { return false; }
  return true;
}

function isValidPrice(value) {
  if (PRICE_ONLY_REGEXP.test(value) || value == '') {
    return true;
  } else {
    return false;
  }
}

/************************************************/
var willLoadSizesTable = false;

jQuery(function() {

  $("[data-toggle='tooltip']").tooltip();
  $("[data-toggle='image-popover']").popover({ html: true, trigger:'hover', placement:'bottom', 
      content:function(){ return "<img class='image-flex' src='" + $(this).data('img') + "'/>" } }
    );

  $('.variant-one-box .color-box').click( clickedSelectionButton );

  $('.variant-option-box .color-box').click( clickedSelectionButton );

  selections = [];

  $('.color-palette .color-box').click(paletteColor_clicked);

  $('.color-palette-preview .reverse .btn').click(function() {
    selections.reverse();
    drawPreview();
  });

  $('.color-palette-wrapper .confirm .btn').click(function(event) {
    paletteValue = $('.color-palette-preview .color-box');
    colorname = paletteValue.attr('data-name');
    colorid = paletteValue.attr('data');
    colorvalue = paletteValue.attr('data-value');
    if (colorvalue && colorvalue.length > 0) {
      if (colorid == undefined || colorid == '') {
        //console.log(" -> Submit to create color " + colorvalue);
      }
      else {
        event.preventDefault();
        //console.log(" -> Add existing color (" + colorid + ") " + colorvalue);
        $("#color_picker_preview_color").val(colorvalue);
        el = makeTippedColorBox(colorid, colorvalue, colorname);
        $('.variant-box-body').append(el);
        $('.color-picker').toggleClass('d-flex');
      }
    }  else {
      paletteValue.css('border', 'solid 2px red').animate({ opacity: -0.2 }, 2000, function() {
          paletteValue.animate({ opacity: '0.5' }, 2000 );
        } );
      event.preventDefault();
    }
  });

  $('.color-palette-heading .close-btn').click(function() {
    $('.color-picker').toggleClass('d-flex');
  });

  $('.color-picker-heading .close-btn').click(function() {
    $('.color-picker-wrapper').hide();
    $('.color-palette-wrapper').show();
  });

  $('.add-variant').click(function(){
    $('.color-palette .color-box').removeClass('selected');
    $('.color-picker').toggleClass('d-flex');

    selections = [];
  });

  $('.color-add').click(function() {
    $('.color-palette-wrapper').hide();
    $('.color-picker-wrapper').show();

    picker.enter();
  });

  loadColorPicker();



  $('.confirm-variant').click(function(){
    selected = $('.variant-box .selected');
    $('.sizes-box thead').empty();
    $('.sizes-box thead').append('<th></th>');
    selected.each(function(idx){
      e = $(this);
      colorvalue = e.attr('data-value');
      colors = colorvalue.split(',');
      colorname = e.attr('data-name');
      colorid = e.attr('data');

      el = makeColorBox(colorid, colorvalue, colorname);

      $('.sizes-box thead').append('<th class="selected" onclick="checkColumn(this)" data-idx="' + (idx + 2) + '">' + el + '</th>');
    });
    $('.sizes-box thead').append('<th></th>');

    $('.sizes-box tbody').empty();
    sizes.forEach(function(s) {
      el = '<tr><td><div class="option-box d-flex jc-sb"><div>' + s + '</div><a class="option-remove" onclick="removeRow(this)"></a></div></td>';
      selected.each(function(e){
        el += '<td class="fs-25"><div class="checkbox"><span class="cr no-border" onclick="checkCell(this)"><input type="checkbox"><i class="cr-icon fa fa-check"></i></span></div></td>';
      });
      el += '<td></td>';
      el += '</tr>';
      $('.sizes-box tbody').append(el);
    });

    w = 200 + 55 * selected.length + 55;
    $('.variant-option-box').css('width', w + 'px');
  });

  $('.size-box thead th.selected').click(function() {

  });

  $('.sizes-box .add-all').click(function() {
    $('.sizes-box thead .color-box').addClass('selected');
    $('.sizes-box tbody input').prop('checked', true);
  });

  $('.checkbox .cr').click(function(){
    checkCell(this);
  });

  $("button[data-table-to-collapse]").click(showAllRows);

  initCurrencyPriceField();
  initCategorySelector();
  initAutoFileUpload();
  initRestrictPriceOnlyInput();
});
