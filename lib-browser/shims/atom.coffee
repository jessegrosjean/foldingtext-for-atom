require './document-register-element'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
CommandRegistery = require './command-registery'
ViewRegistry = require './view-registery'

module.exports =
  Emitter: Emitter
  Disposable: Disposable
  CompositeDisposable: CompositeDisposable

window.atom =
  commands: new CommandRegistery
  views: new ViewRegistry