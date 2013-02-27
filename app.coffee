express = require 'express'
routes = require './routes'
request = require 'request'
xml2js = require 'xml2js'
socketio = require 'socket.io'
app = express.createServer()
io = socketio.listen(app)

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
global.devices = {}
global.tv_code = 2848

get_random_code = () -> Math.floor(Math.random() * 10000)
get_ids = () -> (entry.id for entry in playlist)
get_index = (id) -> get_ids().indexOf id
get_duration = (x) -> Math.floor(x/60) + ':' + ('0'+ x%60).substr(-2)
htmlEscape = (html) -> (html).replace(/&(?!\w+;)/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '\\\'').replace(/"/g, '\\\"').replace(/[\r\n]/g, '<br />')
get_details = (entry) -> title: entry.title[0]._, \
                            id: entry.id[0].split('/').pop(), \
                           src: entry.content[0].$.src, \
                      duration: get_duration(entry['media:group'][0]['yt:duration'][0].$.seconds), \
                   description: htmlEscape(entry['media:group'][0]['media:description'][0]._), \
                     thumbnail: entry['media:group'][0]['media:thumbnail'][1].$.url

#Socket.io
io.sockets.on 'connection', (socket) =>
    socket.on 'playlist add', (data) =>
        socket.broadcast.emit 'playlist add', data
    socket.on 'mobile connect', (data) =>
        if parseInt(data.code) != tv_code
            socket.emit 'connect ack', {success:false, msg:'TV Code is invalid, check again'}
        else if data.nickname of devices
            socket.emit 'connect ack', {success:false, msg:'Nickname is already taken!'}
        else
            devices[data.nickname] = socket
            socket.emit 'connect ack', {success:true}
    socket.on 'mobile chat', (data) =>
        socket.broadcast.emit 'chat message', data
    socket.on 'disconnect', () =>
        for key of devices
            if devices[key] == socket
                delete devices[key]
                break

#Routes
app.get '/view/tv', (req, res) =>
    global.tv_code = get_random_code()
    res.render('list', {
        title: 'Connected TV',
        code: tv_code
    })

app.get '/user/list', (req, res) =>
    res.json (nickname for nickname of devices)

app.get '/playlist/get', (req, res) =>
    res.json playlist
    #io.sockets.emit 'playlist add', {id:'_OBlgSz8sSM', title:'br test'}

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
          res.json item
        parser.parseString body
      catch error
        console.log 'Request error.'
  else
      res.json playlist

app.get '/playlist/like/:id', (req, res) =>
    before = get_index req.params.id
    playlist[before].like += 1
    playlist.sort((item1, item2) -> (item2.like - item2.dislike) - (item1.like - item1.dislike))
    after = get_index req.params.id
    console.log before, after, before != after
    if before != after
        io.sockets.emit 'playlist position', {from:before+1, to:after+1}
    res.json []

app.get '/playlist/dislike/:id', (req, res) =>
    before = get_index req.params.id
    playlist[before].dislike += 1
    playlist.sort((item1, item2) -> (item2.like - item2.dislike) - (item1.like - item1.dislike))
    after = get_index req.params.id
    if before != after
        io.sockets.emit 'playlist position', {from:before+1, to:after+1}
    res.json []

app.get '/feed/:name', (req, res) =>
  request {uri: 'https://gdata.youtube.com/feeds/api/standardfeeds/KR/' + req.params.name}, (err, response, body) =>
    try
      parser = new xml2js.Parser()
      parser.on 'end', (result, err) =>
        res.json (get_details entry for entry in result.feed.entry)
      parser.parseString body
    catch error
      console.log 'Request error.'
      res.json []

app.listen 3000, () =>
  console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env
