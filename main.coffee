# Configuration Files
config = require './config.coffee'

# Requires and Variables
exp = require 'express'
app = exp.createServer()

coffee = require 'coffee-script'
less = require 'less'
fs = require 'fs'
md = require('node-markdown').Markdown
auth = require './auth.coffee'
crypto = require 'crypto'


# Session perstistence implemented with CouchDB
sessionDB = require('connect-couchdb')(exp)

# App Configuration
app.configure () ->
	app.set 'view engine', 'jade'
	app.set 'views', __dirname + '/views'
	app.use exp.errorHandler { dumpExceptions: true, showStack: true }
	app.use exp.methodOverride()
	app.use exp.bodyParser()
	app.use exp.cookieParser()
	app.use exp.session {secret: 'nawollenwirdochmalsehn', store: new sessionDB({host: config.sessionDBHost,name: config.sessionDBName, auth: {username: config.sessionDBUser, password: config.sessionDBPass}, reapInterval: 600000, compactInterval: 300000})}
	app.use exp.compiler { src: __dirname + '/public', dest: __dirname + '/public', enable: ['less'] }
	app.use exp.static __dirname + '/public'	
	app.use auth.middleware()

auth.helpExpress app

# Articler Class
Articler = require('./articler.coffee').Articler
scene = new Articler config.mainDBHost, config.mainDBPort, config.mainDB

app.get '/', (req, res) ->
	scene.findAll (err, docs) ->
		res.render 'index', {
			locals: {
				title: 'Spark.'
				articles: docs
			}
		}
	
app.get '/new', (req, res) ->
	res.render 'new', {
		locals: {
			title: 'Spark.'
				}
			}	

app.post '/new', (req, res) ->
	if (req.session.auth.loggedIn)
		uid = req.session.auth.userId
		scene.save {
			createUserId: uid
			title: req.param 'title'
			body: req.param 'body'
			url: req.param 'url'
			created_at: new Date()
			stories: []
		}, (err, returnedDoc, returnedData) ->
			res.redirect('/'+returnedData.id)
	else res.redirect('/')

app.get '/concept', (req, res) ->
	fs.readFile 'CONCEPT.md', 'ascii', (err, data) ->
		throw err if err
		res.end md data
		
app.get '/:id', (req, res) ->
	scene.findById req.params.id, (err, doc) ->
		if doc 
			res.render 'single', {
				locals:{
					title:"Spark."
					id: req.params.id
					doc: doc.value
				}
			}
		else
			res.redirect('/')

app.post '/:id/add', (req, res) ->
	scene.findById req.params.id, (findErr, originalDoc) ->

		if originalDoc
			tempDoc = originalDoc.value
			uid = req.session.auth.userId
			newStory =  {
				title: req.param "title"
				story: req.param "story"
				createUserId: uid
			}
			
			hash = crypto.createHmac('sha1', 'abcdeg').update(newStory.title+newStory.story+newStory.createUserId).digest('hex')
			
			newStory._id=hash
			
			tempDoc.stories.push newStory
			
			scene.saveById req.params.id, tempDoc, (saveErr, doc, saveRes) ->
				throw saveErr if saveErr
				res.redirect('/'+req.params.id)
		else
			console.log "could not retrieve original document"
			res.redirect('/'+req.params.id)

# Run App
app.listen 14904
console.log 'Server running at http://localhost:14904/'