express = require 'express'
routes = require './routes'
request = require 'request'
eyes = require 'eyes'
xml2js = require 'xml2js'
app = module.exports = express.createServer()

app.configure =>
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use app.router
  app.use express.static(__dirname + '/public')

app.configure 'development', () =>
  app.use express.errorHandler({ dumpExceptions: true, showStack: true })

app.configure 'production', () =>
  app.use express.errorHandler()

#Routes

app.get '/', (req, res) =>
  request {uri: 'https://gdata.youtube.com/feeds/api/standardfeeds/most_popular'}, (err, response, body) =>
    if err and response.statusCode != 200
      console.log 'Request error.'

    parser = new xml2js.Parser()
    parser.on 'end', (result) =>
      items = ({'title': entry.title[0]._, \
                'src': entry.content[0].$.src, \
                'thumbnail': entry['media:group'][0]['media:thumbnail'][0].$.url} for entry in result.feed.entry)
      res.json(items)
    parser.parseString body

app.listen 3000, () =>
  console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env
