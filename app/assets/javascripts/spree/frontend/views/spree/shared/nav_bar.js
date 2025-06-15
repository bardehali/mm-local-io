var timerToSearchKeywordChange
var headerSpree
var headerOverlay
var searchIcons
var searchDropdown
var searchBox

function toggleSearchBar() {
  var kw = searchBox['value']
  if (kw == '' || searchDropdown.classList.contains('shown')) {
    headerSpree.classList.remove('above-overlay')
    .classList.remove('shown')
    searchDropdown.classList.remove('shown')
  } else {
    headerSpree.classList.add('above-overlay')
    headerOverlay.classList.add('shown')
    searchDropdown.classList.add('shown')
    $(searchDropdown).click()
  }
}

function toggleOverlayOn() {
  if (!headerOverlay.classList.contains('shown')) {
    headerSpree.classList.add('above-overlay')
    headerOverlay.classList.add('shown')
  }
}

function toggleOverlayOff() {
  if (headerOverlay.classList.contains('shown')) {
    headerSpree.classList.remove('above-overlay')
    headerOverlay.classList.remove('shown')
  }
  cancelSearchDropdown()
}

function countDownSearchKeywordsChange() {
  var kw = searchBox['value']
  if (typeof(timerToSearchKeywordChange) != 'undefined' ) {
    clearTimeout(timerToSearchKeywordChange);
    timerToSearchKeywordChange = undefined
  }
  if (kw != undefined && kw.length > 0) {
    timerToSearchKeywordChange = setTimeout(predictSearchKeywords, 500)
  }
}

function predictSearchKeywords() {
  var kw = searchBox['value']
  if (kw == undefined || kw.length < 1)
  {
    cancelSearchDropdown()
    toggleOverlayOff()
  }
  else
  {
    if (typeof(timerToSearchKeywordChange) != 'undefined' ) {
      clearTimeout(timerToSearchKeywordChange);
      timerToSearchKeywordChange = undefined
    }
    jQuery.ajax({
      url: "/search_keywords?keywords=" + kw,
      dataType: 'script'
    }).done(function (data) {
      toggleOverlayOn()
    })
  }
}


function dropdownFocusOut(){
  var kw = searchBox['value']
  if (searchDropdown != undefined && ($(searchDropdown).hasClass('show') == false || kw.length < 1 ) ) {
    cancelSearchDropdown()
    toggleOverlayOff()
  }
}

function showSearchDropdown()
{
  searchDropdown.classList.add('above-overlay')
  $(searchDropdown).dropdown('show')
  $(searchDropdown).focus()
}

function cancelSearchDropdown() {
  searchDropdown.classList.remove('above-overlay')
  $(searchDropdown).dropdown('hide')
  $(searchDropdown).empty()
}


$(document).ready(function() {
  headerSpree = document.querySelector('.header-spree')
  headerOverlay = document.getElementById('overlay')
  searchIcons = document.querySelectorAll('#nav-bar .search-icons')[0]
  searchDropdown = document.querySelectorAll('.search-container .dropdown-menu')[0]
  searchBox = document.querySelectorAll('.search-container .inline-search-box')[0]

  if (searchIcons !== undefined) {
    searchIcons.addEventListener(
      'click',
      toggleSearchBar,
      false
    )
  }

  if (searchBox != undefined) {
    searchBox.addEventListener(
      'keyup',
      predictSearchKeywords,
      false
    )
    searchBox.addEventListener(
      'focusout',
      dropdownFocusOut,
      false
    )

    /*
    headerSpree.addEventListener(
      'focusout', dropdownFocusOut, false
    )
    searchDropdown.addEventListener(
      'focusout',
      dropdownFocusOut,
      false
    ) */
  }

})
