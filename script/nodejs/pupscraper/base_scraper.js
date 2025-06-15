
/* 2) subdomain 3) host name w/o subdomain and extension 4) extension */

const puppeteer = require('puppeteer');
const fs = require("fs");
const urlModule = require('url');

HOST_PARTS_REGEXP = /^((\w+)\.)?(\w+)\.(\w+(\w{2,3})?)$/

function BaseScraper() {
}
module.exports = BaseScraper;

var AliexpressScraper = require('./aliexpress_scraper');

BaseScraper.prototype = {
  scraperClassForURL: function(url) {
    const urlModule = require('url');
    var uri = urlModule.parse(url, true);
    var urlMatch = uri.host.match(HOST_PARTS_REGEXP);
    var sld = (urlMatch) ? urlMatch[3] : uri.host;
    //console.log("| of", url, "its SLD is", sld );
    var c = BaseScraper;
    if (sld != undefined) {
      if (sld == 'aliexpress' || sld.indexOf('localhost') == 0) {
        c = AliexpressScraper;
      }
    }
    return c;
  },
  whatPageType: function(url) {
    return 'index';
  },
  toString: function() {
    return 'BaseScraper';
  },

  savePageSource: async function(url, outputFile) {
    const browser = await puppeteer.launch( { headless: true });
    const page = await browser.newPage();

    //uri = urlModule.parse(url, true);
  
    await page.goto(url, { waitUntil: 'domcontentloaded'});
    await page.waitFor(10000);
  
    const html = await page.content(); // evaluate(() => { return '<html><head>'+ document.head.innerHTML + '</head><body>'+ document.body.innerHTML + '</body></html>'; });

    // const noProtocol = /["'](\/\/[^"']+)["']/ig;
    // html.replace(noProtocol, uri.protocol + "$1")
    fs.writeFile(outputFile, html, (err)=> { if(err){ throw err; } });

    browser.close();

    return html;
  },

  scrapeProduct: async function(page) {
    return {};
  },
  /**
  * 'indexPages': ['http://morepages.html', 'http://anotherpage']
  * 'productPages': ['http://oneproduct', 'http://twoproduct']
  * 'products': [{}, {}]
  */
  scrapePages: async function(url, shouldScrapeProducts = false, filePath = undefined) {
    return { indexPages:[], productPages:[], products:[] };
  },
  fetchProductLinks: function(el) {
    return [];
  },
  fetchIndexLinks: function(el) {
    return [];
  },
  fetchStoreData: function(el) { return {}; },

  /**
   * Common scraper methods
   */
  autoScroll: async function (page) {
    await page.evaluate(async () => {
      await new Promise((resolve, reject) => {
        var totalHeight = 0;
        var distance = 100;
        var timer = setInterval(() => {
          var scrollHeight = document.body.scrollHeight;
          window.scrollBy(0, distance);
          totalHeight += distance;
          if(totalHeight >= scrollHeight){
            clearInterval(timer);
            resolve();
          }
        }, 100);
      });
    });
  },

  /**
   * More element specific wait for dynamic page to execute and render in browser.
   */
  waitAndLog: async (page, selector, timeout = 30000) => {
    const start = Date.now();
    let myElement = await page.$(selector);
    while (!myElement) {
      await page.waitFor(500); // wait 0.5s each time
      const alreadyWaitingFor = Date.now() - start;
      if (alreadyWaitingFor > timeout) {
        throw new Error(`Waiting for ${selector} timeouted after ${timeout} ms`);
      }
      // console.log(`Waiting for ${selector} for ${alreadyWaitingFor}`);
      myElement = await page.$(selector);
    }
    // console.log(`Selector ${selector} appeared on the page!`)
    return myElement;
  },
}
