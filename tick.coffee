Bitstamp = require 'bitstamp'
_ = require 'underscore'
b = new Bitstamp()

time = parseInt process.argv[process.argv.length - 1]
console.log "Ticking every #{time} milliseconds"



trades = 0
max_spread = 0

FEES_PER_TX = 0.005

btc_balance = 1
usd_balance = 0

DATA = []

massage_data = (err, data) ->

  return if err

  [bid, bid_vol] = data.bids[0].map parseFloat
  [ask, ask_vol] = data.asks[0].map parseFloat

  result =
    time: Date.now()
    bid:
      val: bid
      vol: bid_vol
    ask:
      val: ask
      vol: ask_vol
    spread:
      val:  ask - bid
      vol: _.min [bid_vol, ask_vol]
      percent: (ask - bid) / ask * 100

  if result.spread.percent > max_spread
    max_spread = result.spread.percent

  DATA.push result

  console.log "#{time_now()} INFO: bid: #{bid_vol.toFixed(4)} @ #{ bid.toFixed(4) }  ask: #{ask_vol.toFixed(4)} @ #{ask.toFixed(4)}  spread: #{ result.spread.percent.toFixed(4) }% max: #{ max_spread.toFixed(4) }%"
  trade result

tick = ->
  # b.ticker tock
  b.order_book massage_data
  setTimeout tick, time

ppb = (price) -> price / bits_ber_btc

time_now = ->
  date = new Date()
  date.toString().replace( /GMT.*$/, '' )

trade = ({bid, ask, spread}) -> 

  if btc_balance > 0 and spread.percent > FEES_PER_TX * 100
    trades++

    # sell btc for usd
    btc_balance -= spread.vol
    ask_cost = ask.val * spread.vol
    ask_fee = ask_cost * FEES_PER_TX
    usd_balance += ask_cost - ask_fee

    #buy btc with usd
    bid_cost = bid.val * spread.vol
    bid_fee = bid_cost * FEES_PER_TX
    usd_balance -= bid_cost + bid_fee
    btc_balance += spread.vol

    console.log "#{time_now()} TRADED #{trades}: vol: #{spread.vol} btc: #{btc_balance} usd: #{usd_balance}"

tick()


http = require 'http'
url = require 'url'
stat = require 'node-static'

PORT = 8080

file = new stat.Server '.'


getJSONPCallback = (req) ->
  url_parts = url.parse(req.url, true)
  query = url_parts.query
  if !url_parts.query or !url_parts.query.callback
    false
  else
    url_parts.query.callback 

server = http.createServer (req, res) ->

  url_parts = url.parse(req.url, true)

  if url_parts.pathname is '/data'
    callback = getJSONPCallback( req )
    data = JSON.stringify( DATA )
    resp = ";#{callback}(#{data});"

    res.writeHead(200, {'Content-Type': 'text/javscript'})
    res.end( resp )
  else 
    file.serveFile( './index.html', 200, {}, req, res )

server.listen( PORT, '127.0.0.1' )


console.log("Server running at http://localhost:#{PORT}/")