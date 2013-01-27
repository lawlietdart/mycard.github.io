class Server extends Spine.Model
  @configure "Server", "name", "ip", "port", "index"
  @extend Spine.Model.Ajax
  @url: "/servers.json"

class Servers extends Spine.Controller
  constructor: ->
    super
    Server.bind "refresh", @render
    Server.one "refresh", @connect
  render: =>
    @html $('#server_template').tmpl Server.all()
    @el.multiselect(
      noneSelectedText: '房间筛选'
      selectedText: '房间筛选'
      header: false
      minWidth: 'auto'
      classes: 'server_filter'
    ).bind "multiselectclick", (event, ui)->
      Room.trigger 'refresh'
  connect: =>
    wsServer = 'ws://mycard-server.my-card.in:9998'
    websocket = new WebSocket(wsServer);
    websocket.onopen = ->
      console.log("websocket: Connected to WebSocket server.")
    websocket.onclose = ->
      console.log("websocket: Disconnected");
    websocket.onmessage = (evt)->
      #console.log('Retrieved data from server: ' + evt.data)
      rooms = JSON.parse(evt.data)
      for room in rooms
        if room._deleted
          Room.find(room.id).destroy() if Room.exists(room.id)
      Room.refresh (room for room in rooms when !room._deleted)
    websocket.onerror = (evt)->
      console.log('websocket: Error occured: ' + evt.data);

class Room extends Spine.Model
  @configure "Room", "name", "status", "private", "rule", "mode", "start_lp"
  @belongsTo 'server', Server

class Rooms extends Spine.Controller
  events:
    'click .room': 'clicked'
  constructor: ->
    super
    Room.bind "refresh", @render
  render: =>
    @html $('#room_template').tmpl _.sortBy(_.filter(Room.all(), @filter), @sort)

  filter: (room)->
    _.find $('#servers').multiselect('getChecked'), (e)->
      parseInt(e.value) == room.server_id
  sort: (room)->
    [
      if room.status == "wait" then 0 else 1,
      room.private
    ]
  clicked: (e)->
    room = $(e.target).tmplItem().data
    if room.private
      $('#join_private_room')[0].reset()
      $('#join_private_room').data('room_id', room.id)
      $('#join_private_room_dialog').dialog('open')
    else
      mycard.join(room.server().ip, room.server().port, mycard.room_name(room.name, null, room.pvp, room.rule, room.mode, room.start_lp))

login = (username, password)->
  #Candy.Core.Event.Jabber.Presence = (msg)->
  #  Candy.Core.log('[Jabber] Presence');
  #  msg = $(msg);
  #  if(msg.children('x[xmlns^="' + Strophe.NS.MUC + '"]').length > 0)
  #    if (msg.attr('type') == 'error')
  #      self.Jabber.Room.PresenceError(msg);
  #    else
  #      self.Jabber.Room.Presence(msg);
  #  else
  #    alert msg
  #  true
  Candy.init('http://s70.hebexpo.com:5280/http-bind/',
    core:
      debug: false,
      autojoin: ['mycard@conference.my-card.in'],
    view:
      resources: '/vendor/candy/res/',
      language: 'cn'
  )
  Candy.Util.getPosTopAccordingToWindowBounds = (elem, pos)->
    windowHeight = $(document).height()
    elemHeight   = elem.outerHeight()
    marginDiff = elemHeight - elem.outerHeight(true)
    backgroundPositionAlignment = 'top';
    pos -= relative = $('#candy').offset().top
    if (pos + elemHeight >= windowHeight - relative)
      pos -= elemHeight - marginDiff;
      backgroundPositionAlignment = 'bottom';
    return { px: pos, backgroundPositionAlignment: backgroundPositionAlignment };

  CandyShop.InlineImages.init();
  Candy.View.Template.Login.form = $('#login_form_template').html()
  Candy.Util.setCookie('candy-nostatusmessages', '1', 365);
  Candy.Core.connect(username, password)

  $('.xmpp').click ->
    Candy.View.Pane.PrivateRoom.open($(this).data('jid'), $(this).data('nick'), true, true)

  #window.onunload = window.onbeforeunload
  window.onbeforeunload = null
  $('#candy').show()

$(document).ready ->
  #stroll.bind( '.online_list ul' );
  if jid = Candy.Util.getCookie('jid')
    login(jid, Candy.Util.getCookie('password'))

  $('#new_room_dialog').dialog
    autoOpen:false,
    resizable:false,
    title:"建立房间"

  $('#join_private_room_dialog').dialog
    autoOpen:false,
    resizable:false,
    title:"加入私密房间"

  new_room = $('#new_room')[0]
  new_room.pvp.onchange = ->
    if @checked
      new_room.mode.value = 1 if new_room.mode.value == '2'
      new_room.rule.value = 0
      new_room.start_lp.value = 8000
  new_room.mode.onchange = ->
    if @value == '2'
      new_room.pvp.checked = false
  new_room.rule.onchange = ->
    if @value != '0'
      new_room.pvp.checked = false
  new_room.start_lp.onchange = ->
    if @value != '8000'
      new_room.pvp.checked = false

  new_room.onsubmit = (ev)->
    ev.preventDefault()
    $('#new_room_dialog').dialog('close')

    servers = Server.all()
    server = servers[Math.floor Math.random() * servers.length]
    mycard.join server.ip, server.port, mycard.room_name(@name.value, @password.value, @pvp.checked, parseInt(@rule.value), parseInt(@mode.value), parseInt(@start_lp.value))

  $('#join_private_room').submit (ev)->
    ev.preventDefault()
    $('#join_private_room_dialog').dialog('close')

    if @password.value
      room_id = $(this).data('room_id')
      if Room.exists room_id
        room = Room.find(room_id)
        mycard.join(room.server().ip, room.server().port, mycard.room_name(room.name, @password.value, room.pvp, room.rule, room.mode, room.start_lp))
      else
        alert '房间已经关闭'

  $('#new_room_button').click ->
    new_room.reset()
    new_room.name.value = Math.floor Math.random() * 1000
    $('#new_room_dialog').dialog('open')

  #$('#login_domain').combobox()

  #$('#login_dialog').dialog
  #  autoOpen:false,
  #  resizable:false,
  #  title:"用户登录"

  $('#login_button').click ->
    login()
    #$('#login_dialog').dialog 'open'

  #$('#login').submit ->
  #  if @node.value and @domain.value and @password.value
  #    login(@node.value, @password.value, @domain.value)
  #  $('#login_dialog').dialog 'close'
  #  false

  rooms = new Rooms(el: $('#rooms'))
  servers = new Servers(el: $('#servers'))
  Server.fetch()


