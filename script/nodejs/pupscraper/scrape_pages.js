/** 
 * Scrape multiple pages using the same browser. 
 * Standout prints a joint JSON hash of URLs of 
 * This way avoids spamming server with multiple single page requests.
 * Arguments: 
 *  (FETCH_PRODUCTS) would requests those product URLs and parse into 'products'list
 *  $page_url_1, $page_url_2, ...
 *  OR by $page_url $saveSourceFilePath.html
 * Output JSON format:
 *   'indexPages': ['http://morepages.html', 'http://anotherpage']
 *   'productPages': ['http://oneproduct', 'http://twoproduct']
 *   'products': [{}, {}]
*/
var actualArgv = process.argv.slice(2);
var urls = [];
var url = actualArgv.shift();
var filePath;
while (url != undefined) {
  if (url.endsWith('.html') ) {
    filePath = url;
  } else {
    urls.push( url );
  }
  url = actualArgv.shift();
}

const BaseScraper = require('./base_scraper');

const scrapePages = async (urls) => {
  // scraper
  var localUrl = urls[0];
  const scraperClass = (new BaseScraper()).scraperClassForURL(localUrl);
  var scraper = new scraperClass();

  var totalPages = {indexPages:[], productPages:[], products:[]};
  for (var i = 0; i < urls.length; i++){
    const pages = await scraper.scrapePages(urls[i], false, filePath );
    totalPages['indexPages'] = totalPages['indexPages'].concat(pages['indexPages']);
    totalPages['productPages'] = totalPages['productPages'].concat(pages['productPages']);
    totalPages['products'] = totalPages['products'].concat(pages['products']);
  }
  console.log( JSON.stringify(totalPages) );
  /*console.log("  count of indexPages:", totalPages['indexPages'].length );
  console.log("  count of productPages:", totalPages['productPages'].length );
  console.log("  count of products:", totalPages['products'].length );*/

}

scrapePages(urls);