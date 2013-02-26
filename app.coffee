express = require 'express'
routes = require './routes'
request = require 'request'
xml2js = require 'xml2js'
app = module.exports = express.createServer()

app.configure =>
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.set 'view options', {layout:false}
  app.set 'jsonp callback', true
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use app.router
  app.use express.static(__dirname + '/public')

app.configure 'development', () =>
  app.use express.errorHandler({ dumpExceptions: true, showStack: true })

app.configure 'production', () =>
  app.use express.errorHandler()

global.playlist = []
get_ids = () -> (entry.id for entry in playlist)
get_index = (id) -> get_ids().indexOf id
get_duration = (x) -> Math.floor(x/60) + ':' + ('0'+ x%60).substr(-2)
htmlEscape = (html) -> (html).replace(/&(?!\w+;)/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/[\r\n]/g, '<br />')
get_details = (entry) -> title: entry.title[0]._, \
                            id: entry.id[0].split('/').pop(), \
                           src: entry.content[0].$.src, \
                      duration: get_duration(entry['media:group'][0]['yt:duration'][0].$.seconds), \
                   description: htmlEscape(entry['media:group'][0]['media:description'][0]._), \
                     thumbnail: entry['media:group'][0]['media:thumbnail'][1].$.url

#Routes
app.get '/view/tv', (req, res) =>
    res.render('list', {
        title: 'Connected TV',
    })

app.get '/playlist/get', (req, res) =>
    playlist.sort((item1, item2) => if item1.like - item1.dislike > item2.like - item2.dislike then 0 else 1)
    res.json playlist

app.get '/playlist/add/:id', (req, res) =>
  if req.params.id not in get_ids
    request {uri: 'http://gdata.youtube.com/feeds/api/videos/' + req.params.id}, (err, response, body) =>
      try
        parser = new xml2js.Parser()
        parser.on 'end', (result) =>
          item = get_details result.entry
          item['like']    = 0
          item['dislike'] = 0
          playlist.push item
          res.json playlist
        parser.parseString body
      catch error
        console.log 'Request error.'
  else
      res.json playlist

app.get '/playlist/like/:id', (req, res) =>
    playlist[get_index req.params.id].like += 1
    res.json []

app.get '/playlist/dislike/:id', (req, res) =>
    playlist[get_index req.params.id].dislike += 1
    res.json []

app.get '/feed/:name', (req, res) =>
  request {uri: 'https://gdata.youtube.com/feeds/api/standardfeeds/' + req.params.name}, (err, response, body) =>
    try
      parser = new xml2js.Parser()
      parser.on 'end', (result) =>
        res.json (get_details entry for entry in result.feed.entry)
      parser.parseString body
    catch error
      console.log 'Request error.'
      res.json []

app.listen 3000, () =>
  console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env
