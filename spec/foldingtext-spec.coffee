path = require 'path'
outlinePath = path.join(__dirname, 'fixtures/outline.ftml')

describe 'FoldingText', ->
  [workspaceElement, activationPromise] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    activationPromise = atom.packages.activatePackage('foldingtext-for-atom')

  it 'should open outline editor in workspace pane', ->
    expect(workspaceElement.querySelector('ft-outline-editor')).not.toExist()

    waitsForPromise ->
      activationPromise.then ->
        atom.workspace.open(outlinePath)

    runs ->
      expect(workspaceElement.querySelector('ft-outline-editor')).toExist()
      outlineEditor = atom.workspace.getActivePaneItem()
      outlineEditor.getPath().should.equal(outlinePath)
      outlineEditor.outline.root.firstChild.bodyText.should.equal('one')

  it 'should apply search to editor based on query parameter', ->
    waitsForPromise ->
      activationPromise.then ->
        atom.workspace.open(outlinePath + '?query=one')

    runs ->
      outlineEditor = atom.workspace.getActivePaneItem()
      outlineEditor.getPath().should.equal(outlinePath)
      outlineEditor.getSearch().query.should.equal('one')
      waitsForPromise ->
        atom.workspace.open(outlinePath + '?query=two').then ->
          outlineEditor.getSearch().query.should.equal('two')

  describe 'FoldingText Service', ->
    [foldingTextService] = []

    beforeEach ->
      waitsForPromise ->
        activationPromise.then (pack) ->
          foldingTextService = pack.mainModule.provideFoldingTextService()
          atom.workspace.open(outlinePath)

    it 'should provide service', ->
      foldingTextService.should.be.ok

    it 'should expose classes', ->
      foldingTextService.Item.should.be.ok
      foldingTextService.Outline.should.be.ok
      foldingTextService.Mutation.should.be.ok
      foldingTextService.OutlineEditor.should.be.ok

    it 'should get outline editors', ->
      foldingTextService.getOutlineEditors().length.should.equal(1)
