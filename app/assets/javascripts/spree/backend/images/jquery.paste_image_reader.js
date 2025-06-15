(function($) {
  var defaults;
  $.event.fix = (function(originalFix) {
    return function(event) {
      event = originalFix.apply(this, arguments);
      if (event.type.indexOf('copy') === 0 || event.type.indexOf('paste') === 0) {
        event.clipboardData = event.originalEvent.clipboardData;
      }
      return event;
    };
  })($.event.fix);
  defaults = {
    callback: $.noop,
    matchType: /image.*/
  };
  return $.fn.pasteImageReader = function(options) {
    if (typeof options === "function") {
      options = {
        callback: options
      };
    }
    options = $.extend({}, defaults, options);
    return this.each(function() {
      var $this, element;
      element = this;
      $this = $(this);
      return $this.bind('paste', function(event) {
        var clipboardData, found;
        found = false;
        clipboardData = event.clipboardData;
        return Array.prototype.forEach.call(clipboardData.types, function(type, i) {
          var file, reader;
          if (found) {
            return;
          }
          if (type.match(options.matchType) || clipboardData.items[i].type.match(options.matchType)) {
            file = clipboardData.items[i].getAsFile();
            reader = new FileReader();
            reader.onload = function(evt) {
              return options.callback.call(element, {
                dataURL: evt.target.result,
                event: evt,
                file: file,
                name: file.name
              });
            };
            reader.readAsDataURL(file);
            return found = true;
          }
        });
      });
    });
  };
})(jQuery);


function copy(text) {
  var t = document.getElementById("base64");
  t.select();
  try {
    var successful = document.execCommand("copy");
    var msg = successful ? "successfully" : "unsuccessfully";
    alert("Base64 data coppied " + msg + " to clipboard");
  } catch (err) {
    alert("Unable to copy text");
  }
}

/* From https://mobiarch.wordpress.com/2013/09/25/upload-image-by-copy-and-paste/ */
function handlePaste(e) {
  for (var i = 0 ; i < e.clipboardData.items.length ; i++) {
    var item = e.clipboardData.items[i];
    console.log("Item: " + item.type);
    if (item.type.indexOf("image") == -1) {
      uploadFile(item.getAsFile());
    } else {
      console.log("Discarding image paste data");
    }
  }
}

function selectedPasteTarget() {
  var $this = $(this);
  var bi = $this.css("background-image");
  if (bi != "none") {
    $data.text(bi.substr(4, bi.length - 6));
  }

  $(".paste-target-active").removeClass("paste-target-active");
  $this.addClass("paste-target-active");

  $this.toggleClass("contain");

  $width.val($this.data("width"));
  $height.val($this.data("height"));
  if ($this.hasClass("contain")) {
    $this.css({ width: $this.data("width"), height: $this.data("height"), "z-index": "10" });
  } else {
    $this.css({ width: "", height: "", "z-index": "" });
  }
}

function uploadFile(file) {
  var xhr = new XMLHttpRequest();

  xhr.upload.onprogress = function(e) {
    var percentComplete = (e.loaded / e.total) * 100;
    console.log("Uploaded " + percentComplete + "%");
  };

  xhr.onload = function() {
    if (xhr.status == 200) {
      alert("Sucess! Upload completed");
    } else {
      alert("Error! Upload failed");
    }
  };

  xhr.onerror = function() {
    alert("Error! Upload failed. Can not connect to server.");
  };

  xhr.open("POSTileUploader", true);
  xhr.setRequestHeader("Content-Type", file.type);
  xhr.send(file);
}

var dataURL, filename;
$("html").pasteImageReader(function(results) {
  filename = results.filename, dataURL = results.dataURL;
  $data.text(dataURL);
  $size.val(results.file.size);
  $type.val(results.file.type);
  var img = document.createElement("img");
  img.src = dataURL;
  var w = img.width;
  var h = img.height;
  $width.val(w);
  $height.val(h);
  var activeTarget = $(".paste-target-active");
  $(activeTarget).siblings("input[name='image[image_data]']").val(dataURL);
  $(activeTarget).siblings("input[name='product[uploaded_images][][image_data]']").val(dataURL);
  if ( $(activeTarget).hasClass('auto-upload-file') ) {
    $(activeTarget).siblings("button[type='submit']").click();
  }

  return $(".paste-target-active")
    .css({
      backgroundImage: "url(" + dataURL + ")"
    })
    .data({ width: w, height: h }).addClass('pasted-target');
});

var $data, $size, $type, $width, $height;
$(function() {
  $data = $(".data");
  $size = $(".size");
  $type = $(".type");
  $width = $("#width");
  $height = $("#height");
  $(".paste-target").on("click", selectedPasteTarget);
});

