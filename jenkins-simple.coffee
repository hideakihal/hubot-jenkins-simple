# Description:
#   Interact with your Jenkins CI server with simple interface
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_JENKINS_URL
#   HUBOT_JENKINS_AUTH
#
#   Auth should be in the "user:password" format.
#
# Commands:
#   hubot build <job> - builds the specified Jenkins job
#   hubot build <job> <params> - builds the specified Jenkins job with parameters value value2
#   hubot list <filter> - lists Jenkins jobs
#
# Notes:
#   jekins_config expects a JSON object structured like this:
#
#   { "foo": {
#       "job": "build-foo",
#       "params": "param1,param2"
#     }
#   }
#
#   - "foo" (String) Human readable job you want to invoke.
#   - "job" (String) Name of the Jenkins job you want to invoke.
#   - "params" (String) Comma seperated string of all the parameter keys to be
#     passed to the Jenkins job.
#
# Author:
#   hideakihal 

querystring = require 'querystring'

# Holds a list of jobs, so we can trigger them with a number
# instead of the job's name. Gets populated on when calling
# list.
jobList = []

jenkins_config = {
  "test_job": {
    "job": "test_job",
    "params": "server,command"
  }
}

jenkinsBuild = (msg, buildWithEmptyParameters) ->
    url = process.env.HUBOT_JENKINS_URL

    if jenkins_config?
        CONFIG = jenkins_config
    else
        robot.logger.warning 'jenkins config is not set'
        CONFIG = {}

    environment = querystring.escape msg.match[1] 
    paramValues = msg.match[2].split(' ')
    
    if environment not of CONFIG
      msg.send "Invalid environment: #{environment}"
      msg.send "Valid environments are: #{(key for key of CONFIG)}"
      return

    job = CONFIG[environment].job
    paramKeys = CONFIG[environment].params ||= "BRANCH"
    paramKeys = paramKeys.split(',') 

    if paramKeys.length isnt paramValues.length
      msg.send 'Invalid parameters.'
      msg.send "Valid parameters are: #{(key for key of paramKeys)}"
      return

    count = paramKeys.length - 1
    params = ''
    for i in [0..count]
      params += "#{paramKeys[i]}=#{paramValues[i]}"
      if i isnt count
        params += '&'

    command = if buildWithEmptyParameters then "buildWithParameters" else "build"
    path = if params then "#{url}/job/#{job}/buildWithParameters?#{params}" else "#{url}/job/#{job}/#{command}"
    req = msg.http(path)

    if process.env.HUBOT_JENKINS_AUTH
      auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
      req.headers Authorization: "Basic #{auth}"

    req.header('Content-Length', 0)
    req.post() (err, res, body) ->
        if err
          msg.reply "Jenkins says: #{err}"
        else if 200 <= res.statusCode < 400 # Or, not an error code.
          msg.reply "Build started for #{job} #{url}/job/#{job}"
        else if 400 == res.statusCode
          jenkinsBuild(msg, true)
        else if 404 == res.statusCode
          msg.reply "Build not found, double check that it exists and is spelt correctly."
        else
          msg.reply "Jenkins says: Status #{res.statusCode} #{body}"


jenkinsList = (msg) ->
    url = process.env.HUBOT_JENKINS_URL
    filter = new RegExp(msg.match[2], 'i')
    req = msg.http("#{url}/api/json")

    if process.env.HUBOT_JENKINS_AUTH
      auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
      req.headers Authorization: "Basic #{auth}"

    req.get() (err, res, body) ->
        response = ""
        if err
          msg.send "Jenkins says: #{err}"
        else
          try
            content = JSON.parse(body)
            for job in content.jobs
              # Add the job to the jobList
              index = jobList.indexOf(job.name)
              if index == -1
                jobList.push(job.name)
                index = jobList.indexOf(job.name)
                
              state = if job.color == "red"
                        "FAIL" 
                      else if job.color == "aborted"
                        "ABORTED"
                      else if job.color == "aborted_anime"
                        "CURRENTLY RUNNING"
                      else if job.color == "red_anime"
                        "CURRENTLY RUNNING"
                      else if job.color == "blue_anime"
                        "CURRENTLY RUNNING"
                      else "PASS"

              if (filter.test job.name) or (filter.test state)
                response += "[#{index + 1}] #{state} #{job.name}\n"
            msg.send response
          catch error
            msg.send error

module.exports = (robot) ->
  robot.respond /build\s+([\w\.\-_]+)\s+(.+)?/i, (msg) ->
    jenkinsBuild(msg, false)

  robot.respond /list( (.+))?/i, (msg) ->
    jenkinsList(msg)

  robot.jenkins = {
    list: jenkinsList,
    build: jenkinsBuild
  }

