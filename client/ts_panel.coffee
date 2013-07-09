

Template.turkserver.events =
  "click .ts-adminToggle": (e) ->
    e.preventDefault()
    $("#ts-content").slideToggle()

Template.tsAdmin.adminEnabled = ->
  Session.equals("admin", true)
