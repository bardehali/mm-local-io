/** 
 * Standout prints the JSON hash of product attributes.
 * Arguments: 
 *  (FETCH_PRODUCTS) would requests those product URLs and parse into 'products'list
 *  page_url
 *  filePath [String] optional; the file path to save page source
*/
var actualArgv = process.argv.slice(2);
var url = actualArgv.shift();
var filePath = actualArgv.shift();

const fs = require('fs');
const urlModule = require('url');
const puppeteer = require('puppeteer');
const BaseScraper = require('./base_scraper');
var AliexpressScraper = require('./aliexpress_scraper');

const scrapeProduct = async (browser, url, filePath) => {
  if (browser == null || browser == undefined) {
    browser = await puppeteer.launch( { headless: true });
  }
  const page = await browser.newPage();
  try
  {
    var uri = urlModule.parse(url, true);
    await page.goto('http://' + uri.host);
    await page.waitFor(3000);
    await page.goto(url);

    // scraper
    const scraperClass = (new BaseScraper()).scraperClassForURL(url);
    var scraper = new scraperClass();

    // Execute code in the DOM
    var data = await scraper.scrapeProduct(page);

    if (filePath != undefined && filePath.length > 0) {
      const html = await page.content(); // evaluate(() => { return '<html><head>'+ document.head.innerHTML + '</head><body>'+ document.body.innerHTML + '</body></html>'; });

      fs.writeFile(filePath, html, (err)=> { if(err){ throw err; } });
    }

    console.log( JSON.stringify(data) );
  }
  catch (error) {
    console.log('{"error":"' + error.stack + '"}');
  }
  await browser.close();
}

//console.log("| baseScraper: " + BaseScraper);

scrapeProduct(null, url, filePath );