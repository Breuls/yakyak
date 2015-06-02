Client = require 'hangupsjs'
Q      = require 'q'
login  = require './login'
ipc    = require 'ipc'
fs     = require 'fs'
appmenu = require './appmenu'

client = new Client()

app = require 'app'
BrowserWindow = require 'browser-window'

mainWindow = null

# recorded events
recorded = []

# Quit when all windows are closed.
app.on 'window-all-closed', ->
    app.quit() # if (process.platform != 'darwin')

loadAppWindow = ->
    mainWindow.loadUrl 'file://' + __dirname + '/ui/index.html'

openDevTools = ->
    mainWindow?.openDevTools detach: true

app.on 'ready', ->

    # Create the browser window.
    mainWindow = new BrowserWindow {
        width: 940
        height: 600
        "min-width": 620
        "min-height": 420
    }

    appmenu.attach app, {openDevTools}

    # and load the index.html of the app. this may however be yanked
    # away if we must do auth.
    loadAppWindow()

    # callback for credentials
    creds = ->
        prom = login(mainWindow)
        # reinstate app window when login finishes
        prom.then -> loadAppWindow()
        auth: -> prom

    client.connect(creds).then ->
        ipc.on 'reqinit', sendInit
        sendInit()
    .done()

    # sends the init structures to the client
    sendInit = -> mainWindow.webContents.send 'init',
        init: client.init
        recorded: recorded

    # propagate stuff client does
    ipc.on 'sendchatmessage', (ev, {conv_id, segs, client_generated_id, image_id, otr}) ->
        client.sendchatmessage(conv_id, segs, image_id, otr, client_generated_id).then (r) ->
            mainWindow.webContents.send 'sendchatmessage:result', r

    ipc.on 'setpresence', -> client.setpresence(true)
    ipc.on 'updatewatermark', (ev, conv_id, time) ->
        client.updatewatermark conv_id, time
    ipc.on 'getentity', (ev, ids) -> client.getentitybyid(ids).then (r) ->
        mainWindow.webContents.send 'getentity:result', r

    # propagate these events to the renderer
    require('./ui/events').forEach (n) ->
        client.on n, (e) ->
          recorded.push [n, e]
          mainWindow.webContents.send n, e


    # Emitted when the window is closed.
    mainWindow.on 'closed', ->
        mainWindow = null
