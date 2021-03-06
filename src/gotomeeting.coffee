# Description
#   GoToMeeting hubot script
#
# Configuration:
#   HUBOT_GOTOMEETING_USER_TOKEN : GoToMeeting User OAuth Token
#
# Commands:
#   hubot create meeting
#   hubot create meeting <name>
#   hubot create recurring meeting <name>
#   hubot host meeting <name>
#   hubot join meeting <name>
#   hubot list meetings
#
# Author:
#   Devon Blandin <dblandin@gmail.com>

Path                 = require('path')
Meeting              = require(Path.join(__dirname, 'meeting'))
MeetingListFormatter = require(Path.join(__dirname, 'formatters/meeting_list_formatter'))
MeetingStore         = require(Path.join(__dirname, 'meeting_store'))
_                    = require('lodash')
apiRoot              = 'https://api.citrixonline.com/G2M/rest'
token                = process.env.HUBOT_GOTOMEETING_USER_TOKEN

ensureConfig = (msg) ->
  if process.env.HUBOT_GOTOMEETING_USER_TOKEN?
    true
  else
    msg.send 'HUBOT_GOTOMEETING_USER_TOKEN is not set.'

    false

findMeeting = (meetings, name) ->
  params = _.find(meetings, (meeting) -> meeting.subject is name)

  new Meeting(params) if params

module.exports = (robot) ->
  robot.respond /host meeting (.*)/i, (msg) ->
    return unless ensureConfig(msg)

    name  = msg.match[1].trim()
    store = new MeetingStore()

    store.all()
      .then (response) ->
        if meeting = findMeeting(response.data, name)
          meeting.start()
            .then (response) ->
              hostURL = response.data.hostURL

              msg.send("Host meeting '#{name}' at #{hostURL}")

  robot.respond /join meeting (.*)/i, (msg) ->
    return unless ensureConfig(msg)

    name  = msg.match[1].trim()
    store = new MeetingStore()

    store.all()
      .then (response) ->
        if meeting = findMeeting(response.data, name)
          msg.send "Join meeting '#{meeting.name()}' at #{meeting.joinUrl()}\nPhone: #{meeting.callInfo()}"
        else
          msg.send("Sorry, I can't find that meeting.")

  robot.respond /create meeting\s?(.*)/i, (msg) ->
    return unless ensureConfig(msg)

    user = msg.message.user
    now  = new Date()

    name = msg.match[1] || "#{user.name}-#{now.getTime()}"

    store = new MeetingStore()

    store.create(name: name)
      .then (response) ->
        meeting = new Meeting(response.data[0])

        msg.send "I've created the meeting '#{name}' for you.\nJoin: #{meeting.joinUrl()}"

  robot.respond /create recurring meeting\s?(.*)/i, (msg) ->
    return unless ensureConfig(msg)

    user = msg.message.user
    now  = new Date()

    name = msg.match[1]

    unless name?
      msg.send 'A recurring meeting needs a name.'

      return

    store = new MeetingStore()

    store.create(name: name, meetingType: 'Recurring')
      .then (response) ->
        meeting = new Meeting(response.data[0])

        msg.send "I've created the recurring meeting '#{name}' for you.\nJoin: #{meeting.joinUrl()}"

  robot.respond /list meetings/i, (msg) ->
    return unless ensureConfig(msg)

    store = new MeetingStore()

    store.all()
      .then (response) ->
        meetings = (new Meeting(params) for params in response.data)

        msg.send new MeetingListFormatter(meetings).message()
