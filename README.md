# hubot-jenkins-simple
Jenkins integration for Hubot with simple interface

## Usage

jekins_config expects a JSON object structured like this

```
jekins_config = {
  "foo": {
    "job": "build-foo",
    "params": "param1,param2"
  }
}
```
- "foo" (String) Human readable job you want to invoke.
- "job" (String) Name of the Jenkins job you want to invoke.
- "params" (String) Comma seperated string of all the parameter keys to be passed to the Jenkins job.

Build jenkins job from hubot

```
@hubot build foo param1 param2
```
