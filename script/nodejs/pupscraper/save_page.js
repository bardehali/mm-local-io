/**
 * Fetch individual page and save evaluated page source to local file.
 * Sytanx:
 *   node save_page.js "http://www.aliexpress.com/somepage" [2nd_argument_optional_to_specific_file_name]
 */

const puppeteer = require('puppeteer');
const fs = require("fs");
const urlModule = require('url');
const BaseScraper = require('./base_scraper');

const savePageSource = async (url, outputFile) => {

  // scraper
  const scraperClass = (new BaseScraper()).scraperClassForURL(url);
  var scraper = new scraperClass();

  await scraper.savePageSource(url, outputFile);
  
} // savePageSource

module.exports = savePageSource;

/*************************************** */
var actualArgv = process.argv.slice(2);
var url = actualArgv.shift();
console.log("URL:", url );
if (url == undefined) {
  console.log("Need to provide URL, in syntax: node save_page.js http://amazon.com/search?q=me ./pages/search/me.html");
  process.exit();
}
var filePath = actualArgv.shift();
console.log("File:", filePath);
if (filePath && fs.access(filePath, fs.constants.W_OK, 
  (err) => {
    console.log("** Cannot write to file: ", err);
  }) )
{

}
if (filePath == undefined){ filePath = __dirname; console.log("At directory: " + filePath); }
try {
  var fileStats = fs.statSync(filePath);
  if (fileStats.isDirectory() ) {
    var uri = urlModule.parse(url, true);
    filePath += '/' + uri.host + uri.pathname.replace(/([^\w\._]+)/ig, '_');
    if (!filePath.endsWith('.html')){ filePath += '.html'; }
  }
} catch (error) {
  console.log("** Problem accessing file: " + filePath);
}
console.log("File now: " + filePath);

savePageSource(url, filePath);