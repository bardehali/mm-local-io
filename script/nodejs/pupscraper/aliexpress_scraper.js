const util = require('util');
const puppeteer = require('puppeteer');
const fs = require("fs");
const urlModule = require('url');

//uri = urlModule.parse(url, true);

function AliexpressScraper() {

}

module.exports = AliexpressScraper;

AliexpressScraper.prototype = {
  productUrlRegexp: /.*\/item(\/.+)?\/(\d+)(\.html)?/i,
  searchUrlRegexp: /.*\/wholesale\?.*searchtext=([\w\+\._]+).*/i,
  categoryUrlRegexp: /.*\/category\/(\w+)\/[\w\._]+/i,
  storeUrlRegexp: /.*\/store\/(\d+)(\?[^\/]+)?$/i,
  storeAllProductsUrlRegexp: /.*\/store\/all\-wholesale\-products\/(\d+)(\.html?)?(\?[^\/]+)?$/i,
  pictureRegexp: /((https?:)?\/\/[\w\-\.]+\/kf\/[\w\-\.]+\/[\w\-\.]+\.(jpg|jpeg|png))/ig,
  thumbnailEndingRegexp: /\.(jpe?g|png|gif)([_\.]\d+x?\d*\.(jpe?g|png|gif))$/i,

  toString: function() {
    return 'AliexpressScraper';
  },
  whatPageType: function(url) {
    const uri = urlModule.parse(url, false);
    if (this.productUrlRegexp.test(uri.pathname) ) { return 'detail'; }
    else if (this.storeUrlRegexp.test(uri.pathname) )  { return 'store'; }
    else if (this.searchUrlRegexp.test(uri.pathname) )  { return 'index'; }
    else { return 'index'; }
  },

  savePageSource: async function(url, outputFile) 
  {
    const browser = await puppeteer.launch( { headless: true });
    const page = await browser.newPage();

    const uri = urlModule.parse(url, true);
    await page.goto(uri.protocol + '//' + uri.hostname);

    await page.waitFor(1000);
    await page.click('.search-key-box input');
  
    console.log("save url:", url);
    await page.goto(url, { waitUntil: 'domcontentloaded'});
    if (this.whatPageType(url) == 'detail') {
      await BaseScraper.prototype.waitAndLog(page, '.product-main');
    } else {
      await BaseScraper.prototype.waitAndLog(page, '.product-container');
    }
  
    const html = await page.content(); // evaluate(() => { return '<html><head>'+ document.head.innerHTML + '</head><body>'+ document.body.innerHTML + '</body></html>'; });

    fs.writeFile(outputFile, html, (err)=> { if(err){ throw err; } });

    browser.close();
    return html;
  },

  scrapeProduct: async function(page) {
    try {
      const pageTitle = await page.title();
      if (pageTitle.match(/page\s+not\s+found/i) ) { return { 'page_url': page.url(), 'error': 'NOT FOUND' }; }

      await page.waitForXPath("//*[@class='product-info']");
      // Lazy load of description
      await page.click(".product-action a:last-child,.product-action button:last-child");
      await page.waitForXPath("//*[@class='product-description']");
      await BaseScraper.prototype.autoScroll(page);

      var attr = await page.evaluate( this.evaluateProductDocument );
      attr['page_url'] = await page.url();
      if (attr['error'] && attr['error'].length > 0) { return attr; }

      var lastImage = await page.$eval(".image-viewer *:nth-child(1) img", function(el) { return el['src']; });
      if (lastImage != undefined) { attr['photos'].push(lastImage); }
      //console.debug("lastImage: " + lastImage);
      //console.debug("| properties ==========================");
      var props = attr['properties'];
      if (props == undefined) { props = {}; }
      for (const pkey in props) {
        let pvalues = props[pkey]
        //console.debug("---- " + pkey + " (" + pvalues.length +") ----");
        
        for (var i = 0; i < pvalues.length; i++)
        {
          var pvalue = pvalues[i];
          //console.debug("* " + pvalue['value'] + " at " + pvalue['xpath']);
          // This click and inspect main picture loaded is not reliable 
          if (pvalue['xpath'] != undefined) {
            //await page.click(pvalue['xpath'], function (e) { return e; } );
            const loadedImage = await page.$eval(".image-viewer *:nth-child(1) img", function(el) { return el['src']; });
            if (lastImage != loadedImage) {
              //pvalue['image'] = loadedImage;
              //console.debug(" -> " + loadedImage);
              //attr['properties'][pkey][i] = pvalue;
            } 
            lastImage = loadedImage;
          }
        }
      };

      //console.debug("| photos "+ attr['photos']);
      //console.debug("| properties now ==========================");
      for (const pkey in props) {
        let pvalues = props[pkey]
        //console.debug("---- " + pkey + " (" + pvalues.length +") ----");
        pvalues.forEach(pvalue => {
          if (pvalue['image'] ) {
            //console.debug("* " + pvalue['value'] + ' => ' + pvalue['image']);
          }
        });
      };
      
      return attr;
    } catch(error) {
      var latest_content = await page.content();
      if (latest_content.match(/item\s+(is\s+)?(no\s+longer|not)\s+available/i) ) {
        return { 'error': { 'name': 'Unavailable'} };
      } else {
        return { 'error': error };
      }
    }
  }, // scrapeProduct

  /** For use within page.evaluate, to parse given document and collect data.
   * @return [Hash] w/ keys: title, price, description, photos, properties
   */
  evaluateProductDocument: function() { 
      var attr = {};
      const thumbnailEndingRegexp = /\.(jpe?g|png|gif)([_\.]\d+x?\d*\.(jpe?g|png|gif))$/i;
      attr['title'] = document.querySelector('.product-title').innerText;
      attr['price'] = document.querySelector('.product-price-value').innerText.match(/(\d+(\.\d+)?)/g ).pop();
      var desc = document.querySelector('.product-description').innerHTML;
      if (desc == undefined || desc == ''){ desc = document.querySelector('.product-detail').innerHTML; }
      attr['description'] = desc;

      attr['photos'] = [];
      for (let thumbnail of document.querySelectorAll(".images-view-list img")) {
        var src = thumbnail['src'];
        var thumbnailExt = src.match(thumbnailEndingRegexp);
        if (thumbnailExt && thumbnailExt.length > 0) {
          src = src.replace( thumbnailExt[2], '');
        }
        if (attr['photos'].includes(src)==false){ attr['photos'].push(src) };
      }
      
      const propValueXpath = 'ul > li .sku-property-image,ul > li .sku-property-text';
      attr['properties'] = {};
      var propIndex = 1;
      for (let skuProperty of document.querySelectorAll(".sku-property") ) {
        var propName = skuProperty.children[0].innerText.trim().replace(':', '');
        var propValues = []; // propertyName: [ { xpath: '...', value: 'Black' } ]

        var propValueIndex = 1;
        const propValuesPath = "ul > li > *[class]";
        for (let propValue of skuProperty.querySelectorAll(propValuesPath) ) {
          var valueH = {  };
          if (propValue.classList[0].endsWith('image') ) {
            valueH['value'] = propValue.querySelector('*[title]')['title'];
            valueH['xpath'] = '.sku-property:nth-child(' + propIndex +') > ul li:nth-child(' + propValueIndex + ') *[class]';
            var imgSrc = propValue.querySelector('img[src]')['src'];
            if (imgSrc && imgSrc != '') {
              var thumbnailExt = imgSrc.match(thumbnailEndingRegexp);
              if (thumbnailExt && thumbnailExt.length > 0) {
                valueH['image'] = imgSrc.replace( thumbnailExt[2], '');
              } else {
                valueH['image'] = imgSrc;
              }
            }
          } else if (propValue.classList[0].endsWith('text') ) {
            valueH['value'] = propValue.innerText;
          }
          propValues.push(valueH);
          propValueIndex++;
        }
        attr['properties'][propName] = propValues;
        propIndex++;
      }

      //console.debug("| store info =======================");
      const storeLink = document.querySelector(".store-info a");
      if (storeLink) {
        var retailStoreId;
        if (storeLink['href']) {
          var storeUrlMatch = storeLink['href'].match(/\/store\/(\d+)(\?[^\/]+)?$/i);
          if (storeUrlMatch){ retailStoreId = storeUrlMatch[1]; }
        }
        attr['store'] = { name: storeLink.innerText, store_url: storeLink['href'], retail_site_store_id: retailStoreId };
      }
      //console.debug( attr['store'] );

      // categories
      attr['categories'] = [];
      const categoryUrlRegexp = /\/category\/(\w+)\/[\w\._]+/i;
      for (let categoryLink of document.querySelectorAll(".breadcrumb a[href]") ) {
        const catMatch = categoryLink['href'].match(categoryUrlRegexp);
        if (catMatch) {
          attr['categories'].push( { name: categoryLink.textContent, url: categoryLink['href'], other_site_category_id: catMatch[1] } );
        }
      }

      return attr;

  }, // evaluateProductDocument

  scrapePages: async function(url, shouldScrapeProducts = false, filePath = undefined) {
    const browser = await puppeteer.launch( { headless: true });
    const page = await browser.newPage();
    page.setViewport({ width: 1200, height: 800 });
    var pages = { 'indexPages': [], 'productPages': [] };
    try {
      var uri = urlModule.parse(url, true);
      const pageType = this.whatPageType(url);
      await page.goto(uri.protocol + '//' + uri.hostname);

      // await page.waitFor(1000);
      await BaseScraper.prototype.waitAndLog(page, '.search-key-box input');
      await page.click('.search-key-box input');
      
      await page.goto(url, { waitUntil: 'domcontentloaded'});
      //console.log("pageType:", pageType );
      if (pageType == 'detail') {
        await BaseScraper.prototype.waitAndLog(page, '.product-main');
      }
      else if (pageType == 'store') {
        // convert to www.aliexpress.com/store/all-wholesale-products/5591298.html
        await BaseScraper.prototype.waitAndLog(page, '.pc-store-nav-Products');
        var html = await page.content();
        //console.log(html);
        console.log("----------------");
        var allProductsUrlM = html.match(/(data\-)href="([^"]*\/store\/all\-wholesale\-products\/(\d+)(\.html?)?(\?[^"]+)?)"/i);
        if (allProductsUrlM) {
          var allProductsUrl = allProductsUrlM[2];
          if (allProductsUrl.startsWith('//')) { allProductsUrl = 'https:' + allProductsUrl; }
          var allUri = urlModule.parse(allProductsUrl, true);
          console.log("  -> "+ allUri.href );
          await page.goto(allUri.href );
          await page.content();
          await BaseScraper.prototype.waitAndLog(page, 'li[class="item"]');
        }
      } 
      else {
        await BaseScraper.prototype.waitAndLog(page, '.product-container .product-card');
      }
      await BaseScraper.prototype.autoScroll(page);
      
      var currentPage = await page.url();
      //console.log("currentPage:", currentPage);
      if (filePath != undefined && filePath.length > 0) {
        const html = await page.content();
        fs.writeFile(filePath, html, (err)=> { if(err){ throw err; } });
      }

      if (pageType == 'index') {
        await page.click('.list-pagination');
        await BaseScraper.prototype.waitAndLog(page, '.next-pagination-list button');
      }
      
      pages = await page.evaluate( this.evaluateIndexPage );
    } catch(error) {
      console.debug("** Error: "+ error);
      console.debug(error.stack);
    }

    // Find more product pages from pagination URLs
    for (var i = 0; i < Math.min(3, pages['indexPages'].length); i++) {
      var u = pages['indexPages'][i];
      if (u == '1') {
        pages['indexPages'][i] = currentPage;
      } else {
        var suburl = currentPage + "&page=" + u;
        pages['indexPages'][i] = suburl;
        //console.log(" -> suburl: ", suburl);
        try {
          await page.goto(suburl, { waitUntil: 'domcontentloaded'});
          await page.click('.list-pagination');
          await BaseScraper.prototype.waitAndLog(page, '.product-container .product-card');
          await BaseScraper.prototype.autoScroll(page);
          var morePages = await page.evaluate( this.evaluateIndexPage );
          pages['productPages'] = pages['productPages'].concat( morePages['productPages'] );
          await page.waitFor(1000);
        } catch(suberror) {
          console.debug("************************** "+ suburl );
          console.debug(suberror);
          console.debug(suberror.stack);
        }
      }
    }

    if (shouldScrapeProducts) 
    {
      for (var pi = 0; pi < pages['productPages'].length; pi++)
      {
        var productUrl = pages['productPages'][pi];
        if (productUrl.match(this.productUrlRegexp) == false) { continue; }
        try {
          await page.goto(productUrl, { waitUntil: 'domcontentloaded'});
          await BaseScraper.prototype.waitAndLog(page, '.product-main');
          var data = await this.scrapeProduct(page);
          if (data != null) { pages['products'].push( data ); }
          await page.waitFor(1000 + Math.random(1000) * 1000 );
        } catch(suberror) {
          //console.debug("************************ "+ productUrl );
          //console.debug(suberror);
          //console.debug(suberror.stack);
        }
      }
    }

    
    browser.close();
    return pages;
  },

  /**
   * Collects URIs into the indexPages and productPages.
   * This is private method within scope of evaluated page, in other words, the 
   * document object, but not the scraper's instance.
   */
  evaluateIndexPage: function() 
  {
    var indexPages = [];
    var productPages = [];
    const searchUrlRegexp = /\/wholesale\?.*searchtext=([\w\+\._]+).*/i;
    for (let a of document.querySelectorAll(".next-pagination-list button, .next-pagination-list a[href]") ) {
      if (a.tagName == 'BUTTON') {
        indexPages.push(a.textContent );
      }
      else if (a['href'].match(searchUrlRegexp) ) {
        indexPages.push(a['href']);
      }
    }
    const productUrlRegexp = /.*\/item(\/.+)?\/(\d+)(\.html)?/i;
    for (let a of document.querySelectorAll(".product-list a[href],.items-list a[href]") ) {
      var url = a['href'];
      // if (typeof(url) == 'undefined'){ url = a['data-href']; }
      var productM = url.match(productUrlRegexp);
      if (productM) {
        productPages.push( productM[0] );
      }
    }
    return { indexPages: indexPages, productPages: productPages, products:[] };
  },

  findAllProductsUrl: function(c) 
  {
    console.log("Given c " + c);
    var actualUrl;
    // /store/all-wholesale-products/5591298.html
    const storeAllProductsUrlRegexp = /.*\/store\/all\-wholesale\-products\/(\d+)(\.html?)?(\?[^\/]+)?$/i;
    console.log("document: " + document);
    debugger;
    for (let a of document.querySelectorAll("a[href], a[data-href]") ) {
      var url = a['data-href'];
      if (typeof(url) == 'undefined'){ url = a['href']; }
      var linkM = url.match(storeAllProductsUrlRegexp);
      if (linkM) {
        actualUrl = linkM[0];
      }
    }
    return actualUrl;
  },

  fetchProductLinks: function(el) {
    const urlModule = require('url');
    var productPages = [];
    for (let a of el.querySelectorAll("a[href],a[data-href]") ) {
      var url = a['href'];
      if (typeof(url) == 'undefined'){ url = a['data-href']; }
      if (url.match(this.productUrlRegexp) ) {
        var uri = urlModule.parse(url, true);
        productPages.push( uri.pathname);
      } 
    }
    return productPages;
  },

  fetchIndexLinks: function(el) {
    var indexPages = [];
    for (let a of el.querySelectorAll(".next-pagination-list button, .next-pagination-list a[href]") ) {
      if (a.tagName == 'BUTTON') {
        indexPages.push(a.textContent );
      }
      else if (a['href'].match(this.searchUrlRegexp) ) {
        indexPages.push(a['href']);
      }
    }
    return indexPages;
  },

  fetchStoreData: function(el) {
    var retailStoreId;
    if (el['href']) {
      var storeUrlMatch = el['href'].match(this.storeUrlRegexp);
      if (storeUrlMatch){ retailStoreId = storeUrlMatch[1]; }
    }
    return { name: el.innerText, store_url: el['href'], retail_site_store_id: retailStoreId };
  }, // fetchStoreData

}

var BaseScraper = require('./base_scraper.js')

util.inherits(AliexpressScraper, BaseScraper);
