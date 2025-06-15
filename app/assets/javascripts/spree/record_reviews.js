var statusCode;
function toggleAllBadImage() {
  var eventTarget = $(this);
  statusCode = eventTarget.attr('data-status-code');
  $( eventTarget.attr('data-target') + ' input[type="hidden"]').each(toggleBadImage);
  if (eventTarget.hasClass('checked')) {
    eventTarget.removeClass('checked').addClass('unchecked');
  } else {
    eventTarget.removeClass('unchecked').addClass('checked');
  }
  window.location.hash = 'mark_next_button';
}

function toggleBadImage() {
  if ($(this).attr('id')) {
    var idMatch = $(this).attr('id').match(/status_code_(\d+)$/);
    if (idMatch != null) {
      var id = idMatch[1];
      if ($(this).val() == '') {
        $(this).val(statusCode);
        $("#product_card_" + id + " .record-review").addClass('bad-main-image').find('.temp-status-overlay').show();
      }
      else if($(this).val() == statusCode) {
        $(this).val('');
        $("#product_card_" + id + " .record-review").removeClass('bad-main-image').find('.temp-status-overlay').hide();
        $('#check_all_bad_image').removeClass('checked').add('unchecked');
      }
    }
  }
}

function resetItsStatusCode() {
  var productId = $(this).attr('data-product-id');
  if (productId) {
    $("#status_code_" + productId).val('');
    $("#product_card_" + productId + " .record-review").removeClass('bad-main-image').find('.temp-status-overlay').hide();
    $('#check_all_bad_image').removeClass('checked').add('unchecked');
  }
}

function reviewLinkStart() {
  $(this).css('border', 'solid 1px blue').addClass('glowing-animation');
}


function clickedStatusMenu() {
  event.preventDefault();
  var targetElement = $(event.target);
  if ( targetElement.attr('data-target') == undefined ) { targetElement = targetElement.parent(); }
  targetElement.removeClass('glowing-animation').css('border','none');
  var menu = $( $(targetElement).attr('data-target') );
  if (menu.css('display') == 'block') { menu.hide(); }
  else { menu.show(); }
}

function EditableField(field)
{
  this.constructor = function() {
    this.field = field;
    this.bindEventHandlers();    
  }

  this.cancelEditMode = function() {
    this.field.siblings('.editable-cancel-edit').click();
  }

  this.enterEditMode = function() {
    event.preventDefault();
    var target = $(this).siblings('.editable-field');
    $(target).prop('disabled', false);
    $(target).removeClass('border-0');
    $(this).addClass('d-none');
    $(target).siblings('.editable-cancel-edit, .editable-update').removeClass('d-none');
  }
  this.exitEditMode = function() {
    if ( $(this).prop('type') != 'submit' ) { event.preventDefault(); }
    var target = $(this).siblings('.editable-field');
    $(target).prop('disabled', true);
    $(target).addClass('border-0');
    $(this).removeClass('d-none');
    $(target).siblings('.editable-edit').removeClass('d-none');
    $(target).siblings('.editable-cancel-edit, .editable-update').addClass('d-none');
  }

  this.bindEventHandlers = function() {
    field.siblings('.editable-edit').click(this.enterEditMode);
    field.siblings('.editable-cancel-edit').click(this.exitEditMode);
  }

  this.constructor();
}

if (typeof(jQuery) != 'undefined') {
  $( function(){
    $('#check_all_bad_image').click(toggleAllBadImage);
    $('.temp-status-overlay[data-product-id]').click(resetItsStatusCode);
    $('.small-status-action-inline a[data-remote]').click(reviewLinkStart);
    $("a[class='small-status-action-inline']").click(reviewLinkStart);
    $(".record-review a[data-toggle='menu']").click(clickedStatusMenu);

    $("[data-toggle='tooltip']").tooltip();
    $("[data-toggle='popover']").popover({ html: true, trigger:'hover', placement:'bottom', 
        content:function(){ return "<img class='image-flex' src='" + $(this).data('img') + "'>" } }
      );
  } );
}