# -----------------------------------------------------------------------------
# Project : Platinium records
# -----------------------------------------------------------------------------
# Author : Edouard Richard                                  <edou4rd@gmail.com>
# -----------------------------------------------------------------------------
# License : MIT licence
# -----------------------------------------------------------------------------
# Creation : 20-Apr-2013
# Last mod : 20-Apr-2013
# -----------------------------------------------------------------------------
window.nasa = {}

Widget   = window.serious.Widget
URL      = new window.serious.URL()
Format   = window.serious.format
Utils    = window.serious.Utils

class nasa.ContribMap extends Widget
    constructor:() ->
        @UIS = {
            cMap: '#sphere'
            locations: '#locations'
        }
        @ACTIONS = []
        @MapAPI = null
        @locations = {}

    bindUI:() =>
        super
        @uis.cMap.earth3d {
            texture: '/static/images/earth1024x1024.jpg',
            dragElement: @uis.locations 
            locationsElement: @uis.locations
            onCreated: @onMapInitialized
        }
        this.getLastContribs()
        @checkUpdate()


    simulateBehavior: () =>
        locations = {
            obj1: {
                alpha: Math.PI / 4,
                delta: 0,
                name: 'location 1'
            },
            obj2: {
              alpha: 1 * Math.PI / 4,
              delta: -2 * Math.PI / 4,
              name: 'location 2'
            },
            obj3: {
              alpha: 2 * Math.PI / 4,
              delta: 0,
              name: 'location 3'
            },
            obj4: {
              alpha: 3 * Math.PI / 4,
              delta: 3 * Math.PI / 4,
              name: 'location 4'
            }
        }
        timeout = 1000
        for key, location  of locations
            do(location, key, self=this, timeout) ->
                timeout += 1000
                window.setTimeout(self.addLocation, timeout, self.MapAPI, location, key)

    getLastContribs: () =>
        $.ajax
            url: '/api/map'
            type: 'GET'
            dataType: 'json'
            success: @onContribReceived
            error: console.log

    addLocation: (map, location, key) =>
        map.options.locations[key] = location
        location.visible = true
        map.options.onInitLocation(location, map)

    createLocation: (contrib) =>
        lat = Math.round(Math.random() * 3) * Math.PI / 4
        lng = Math.round(Math.random() * 3) * Math.PI / 4
        # lng = factor * Math.floor(Math.random * Math.PI / 4 
        # lat = (Math.round(contrib.user.lat)) * Math.PI / 4  
        location = {
            key: contrib._id['$oid']
            alpha: lng
            delta: lat
            name: contrib._id['$oid']
        }

    checkUpdate: () =>
        setInterval(@getLastContribs, 2000)

    randomNegative: () =>
        neg = Math.floor(Math.random())
        if neg == 0
            factor = 1
        else
            factor = -1 
        return factor

    onContribReceived: (data) => 
        for contrib in data
            do(self=this, locations, contrib) ->
                location = self.createLocation(contrib)
                if self.locations[location.key] is undefined
                    self.locations[location.key] = location
                    self.addLocation(self.MapAPI, location, location.key)
        
    onMapInitError: (data) =>
        console.error "An error occured while initliazing google earth: ", data

    onMapInitialized: (mapInstance) =>
        @MapAPI = mapInstance
        # @simulateBehavior()


class nasa.ContribForm extends Widget

	constructor: ->
		@UIS = {
			form	: "form"			
			imageZone 	: "#imageZone"
			imageFile 	: ".imageFile"
			imageLink 	: ".imageLink"
			soundZone	: "#soundZone"
			soundFile 	: ".soundFile"
			soundLink 	: ".soundLink"
			video	    : "video"
			canvas	    : "canvas"
			image	    : "img.avatar"
		}
		@cache = {
			imageZone : null
			soundZone : null
		}
		@ACTIONS = ['snapshot', 'sendImage', 'sendSound']

	bindUI: (ui) =>
		super
		this.relayout()
		this.initForm()

	relayout:()=>

	initForm:() =>
		@initVideo()

	hasGetUserMedia: =>
		return !!(navigator.getUserMedia || navigator.webkitGetUserMedia ||
			navigator.mozGetUserMedia || navigator.msGetUserMedia)

	onFailSoHard: (e) =>
		console.log('Reeeejected!')

	initVideo: =>
		if not @hasGetUserMedia()
			alert('no')
		window.URL = window.URL || window.webkitURL;
		navigator.getUserMedia  = navigator.getUserMedia || navigator.webkitGetUserMedia ||
			navigator.mozGetUserMedia || navigator.msGetUserMedia;
		if navigator.getUserMedia
			navigator.getUserMedia({video: true}, ((localMediaStream) =>
				my_url = window.webkitURL || window.URL
				@uis.video.attr('src', my_url.createObjectURL(localMediaStream))
				@localMediaStream = localMediaStream
				# // Note: onloadedmetadata doesn't fire in Chrome when using it with getUserMedia.
				# // See crbug.com/110938.
				@uis.video.get().onloadedmetadata = console.log
				)
			, @onFailSoHard)
		else
			@uis.video.attr('src', 'somevideo.webm')

	snapshot: =>
		ctx = @uis.canvas[0].getContext('2d')
		if @localMediaStream
			ctx.drawImage(@uis.video[0], 0, 0)
			# // "image/webp" works in Chrome 18. In other browsers, this will fall back to image/png.
			@uis.image.attr('src', @uis.canvas[0].toDataURL('image/webp'))
			# we create a local form
			$form = $("<form enctype=\"multipart/form-data\"></form>")
			# $form.append @uis.fileInputField.clone(true, true)
			form =  new FormData $form[0]
			form.append "avatar", @uis.canvas[0].toDataURL('image/webp')
			# We send the data throw ajax
			$.ajax
				url         : "/api/upload/avatar"
				type        : 'POST'
				success     : console.log
				error       : not console or console.log
				data        : form
				cache       : false
				contentType : false
				processData : false
				xhr         : -> $.ajaxSettings.xhr()

	hasGetUserMedia: () =>
		return !!(navigator.getUserMedia || navigator.webkitGetUserMedia ||	navigator.mozGetUserMedia || navigator.msGetUserMedia)		

	sendImage: =>
		if @uis.imageLink.val() != ""
			@sendMedia('picture', @uis.imageLink.val())
		else
			@sendMedia('picture', @uis.imageFile, true)

	sendSound: =>
		if @uis.soundLink.val() != ""
			@sendMedia('audio', @uis.soundLink.val())
		else
			@sendMedia('audio', @uis.soundFile, true)

	sendMedia: (type, value, bin=false) =>
		if not bin
			data = {
				type : type
				value: value
			}
			$.ajax
				url         : "/api/media"
				type       	: 'POST'
				data       	: data
				dataType   	: 'json'
		else
			# we create a local form
			$form = $("<form enctype=\"multipart/form-data\"></form>")
			# $form.append @uis.fileInputField.clone(true, true)
			form =  new FormData $form[0]
			form.append type, value.prop("files")[0]
			# We send the data throw ajax
			$.ajax
				url         : "/api/upload/#{type}"
				type        : 'POST'
				success     : console.log
				error       : not console or console.log
				data        : form
				cache       : false
				contentType : false
				processData : false
				xhr         : -> $.ajaxSettings.xhr()

class nasa.Navigation extends Widget

	constructor: ->
		@UIS = {
			wrapper : '.wrapper'
			slides	: '.slide'
			nextButtons : '.next'		
		}
		@cache = {
			activeSlide : 0
		}

	bindUI: (ui) =>		
		super
		this.initPositions()
		this.relayout()
		$(window).on('resize',this.relayout)
		@uis.nextButtons.each( (idx, el) => 
			$(el).click(=>
				nextPos = parseInt($(el).parents('.slide').attr('data-position')) + 1
				nextSlide = $('.slide[data-position='+nextPos+']')
				$('html,body').animate({ scrollTop: nextSlide.offset().top})
				@cache.activeSlide  = parseInt(nextPos)
			)
		)

	init:()=>
		$('html,body').scrollTop(0)

	initPositions:() =>
		slideIdx=0
		for slide in @uis.slides
			slide = $(slide)
			slide.attr('data-position', slideIdx)
			slideIdx++

	relayout:()=>
		height = $(window).height()		
		@uis.slides.height(height)
		@ui.find('.autoHeight').height(height)
		@uis.slides.width($(window).width())		
		for slide in @uis.slides
			slide = $(slide)
			slide.css("top",slide.attr('data-position') * height)
		activeSlide = @ui.find('.slide[data-position='+@cache.activeSlide+']')
		$('html,body').scrollTop(@cache.activeSlide * height)

# -----------------------------------------------------------------------------
#
#    Image slider
#
# -----------------------------------------------------------------------------
class nasa.ImageSlider extends Widget
	constructor: ->
		@UIS = {
			image : 'img'
		}
		@images = []
		@currentImageIndex = 0

	bindUI: =>
		super
		$.getJSON '/api/pictures', (data) =>
			@images = data
			@start()

	setImage: (img) =>
		@uis.image.attr('src', img)

	start: =>
		if @images.length <= @currentImageIndex + 1
			@currentImageIndex = 0
		url_img = @images[@currentImageIndex]
		$("<img/>").attr('src', url_img).load =>
			@setImage(url_img)
			@currentImageIndex += 1
			setTimeout(@start, 1000)

start = ->
    $(window).load ()->
        Widget.bindAll()

start()

# EOF