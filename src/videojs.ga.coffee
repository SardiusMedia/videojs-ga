##
# ga
# https://github.com/mickey/videojs-ga
#
# Copyright (c) 2013 Michael Bensoussan
# Licensed under the MIT license.
##

videojs.plugin 'ga', (options = {}) ->
  # this loads options from the data-setup attribute of the video tag
  dataSetupOptions = {}
  if @options()["data-setup"]
    parsedOptions = JSON.parse(@options()["data-setup"])
    dataSetupOptions = parsedOptions.ga if parsedOptions.ga

  defaultsEventsToTrack = [
    'loaded', 'percentsPlayed', 'start',
    'end', 'seek', 'play', 'pause', 'resize',
    'volumeChange', 'error', 'fullscreen'
  ]
  eventsToTrack = options.eventsToTrack || dataSetupOptions.eventsToTrack || defaultsEventsToTrack
  percentsPlayedInterval = options.percentsPlayedInterval || dataSetupOptions.percentsPlayedInterval || 10
  trackPlayedInterval = options.trackPlayedInterval || dataSetupOptions.trackPlayedInterval || false

  eventCategory = options.eventCategory || dataSetupOptions.eventCategory || 'Video'
  # if you didn't specify a name, it will be 'guessed' from the video src after metadatas are loaded
  eventId = options.eventId || dataSetupOptions.eventId

  # if debug isn't specified
  options.debug = options.debug || false

  # init a few variables
  percentsAlreadyTracked = []
  seekStart = seekEnd = 0
  seeking = false
  lastTrackedInterval = 0

  loaded = ->
    unless eventId
      eventId = @currentSrc().split("/").slice(-1)[0].replace(/\.(\w{3,4})(\?.*)?$/i,'')

    if "loadedmetadata" in eventsToTrack
      sendbeacon( eventId, eventId, 'loadedmetadata', true )

    return

  timeupdate = ->
    currentTime = Math.round(@currentTime())
    duration = Math.round(@duration())
    percentPlayed = Math.round(currentTime/duration*100)

    for percent in [0..99] by percentsPlayedInterval
      if percentPlayed == percent && percent not in percentsAlreadyTracked
      		twoDigitPercent = ('0' + percent).slice(-2)
        if "start" in eventsToTrack && percent == 0 && percentPlayed > 0
          sendbeacon( eventId, 'start', 'start playback', true )
          sendbeacon( eventId, 'percent played', twoDigitPercent, true, percent )
        else if "percentsPlayed" in eventsToTrack && percentPlayed != 0
          sendbeacon( eventId, 'percent played', twoDigitPercent, true, percent )

        if percentPlayed > 0
          percentsAlreadyTracked.push(percent)

    if trackPlayedInterval
      if trackPlayedInterval >= currentTime - lastTrackedInterval
         sendbeacon( eventId, 'time played', currentTime, true, currentTime )


    if "seek" in eventsToTrack
      seekStart = seekEnd
      seekEnd = currentTime
      # if the difference between the start and the end are greater than 1 it's a seek.
      if Math.abs(seekStart - seekEnd) > 1
        seeking = true
        sendbeacon( eventId, 'seek start', seekStart, false, seekStart )
        sendbeacon( eventId, 'seek end', seekEnd, false, seekEnd )

    return

  end = ->
    sendbeacon( eventId, 'end', 'end video', true )
    return

  play = ->
    currentTime = Math.round(@currentTime())
    sendbeacon( eventId, 'play', currentTime, true, currentTime)
    seeking = false
    return

  pause = ->
    currentTime = Math.round(@currentTime())
    duration = Math.round(@duration())
    if currentTime != duration && !seeking
      sendbeacon( eventId, 'pause', currentTime , false, currentTime)
    return

  # value between 0 (muted) and 1
  volumeChange = ->
    volume = if @muted() == true then 0 else @volume()
    sendbeacon( eventId, 'volume change', volume , false, volume )
    return

  resize = ->
    sendbeacon( eventId, 'resize', @width() + "*" + @height() , true )
    return

  error = ->
    currentTime = Math.round(@currentTime())
    errorInfo = @error()
    #console.log('error!', error.code, error.type , error.message);
    # XXX: Is there some informations about the error somewhere ?
    sendbeacon( eventId, 'error', JSON.stringify(errorInfo), true, currentTime )
    return

  fullscreen = ->
    currentTime = Math.round(@currentTime())
    if @isFullscreen?() || @isFullScreen?()
      sendbeacon( eventId, 'fullscreen', 'enter', false, currentTime )
    else
      sendbeacon( eventId, 'fullscreen', 'exit', false, currentTime )
    return

  sendbeacon = ( category, action, label, nonInteraction, value ) ->
    # console.log action, " ", nonInteraction, " ", value
    if window.ga
      ga 'send', 'event',
        'eventCategory' 	: category
        'eventAction'		: action
        'eventLabel'		: label
        'eventValue'        : value
        'nonInteraction'	: nonInteraction
    else if window._gaq
      _gaq.push(['_trackEvent', category, action, eventLabel, value, nonInteraction])
    else if options.debug
      console.log("Google Analytics not detected")
    return

  @ready ->
    @on("loadedmetadata", loaded)
    @on("timeupdate", timeupdate)
    @on("ended", end) if "end" in eventsToTrack
    @on("play", play) if "play" in eventsToTrack
    @on("pause", pause) if "pause" in eventsToTrack
    @on("volumechange", volumeChange) if "volumeChange" in eventsToTrack
    @on("resize", resize) if "resize" in eventsToTrack
    @on("error", error) if "error" in eventsToTrack
    @on("fullscreenchange", fullscreen) if "fullscreen" in eventsToTrack

  return 'sendbeacon': sendbeacon
