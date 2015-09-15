path = require 'path'
outlinePath = path.join(__dirname, 'fixtures/outline [loo!]!@#$%^&()-+.ftml')

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
      outlineEditor.outline.root.firstChild.bodyString.should.equal('one')

  describe 'Path Query Parameters', ->
    it 'should apply search to editor based on query parameter', ->
      waitsForPromise ->
        activationPromise.then ->
          atom.workspace.open(outlinePath)

      runs ->
        outlineEditor = atom.workspace.getActivePaneItem()
        outlineEditor.getPath().should.equal(outlinePath)
        waitsForPromise ->
          atom.workspace.open(outlineEditor.outline.getFileURL(query: 'two')).then ->
            outlineEditor.getSearch().query.should.equal('two')

    it 'should hoisted item based on query parameter', ->
      waitsForPromise ->
        activationPromise.then ->
          atom.workspace.open(outlinePath)

      runs ->
        outlineEditor = atom.workspace.getActivePaneItem()
        outline = outlineEditor.outline
        waitsForPromise ->
          atom.workspace.open(outline.getFileURL(hoistedItem: outline.getItemForID('2'))).then ->
            outlineEditor.getHoistedItem().bodyString.should.equal('two')

    it 'should expand item based on query parameter', ->
      waitsForPromise ->
        activationPromise.then ->
          atom.workspace.open(outlinePath)

      runs ->
        outlineEditor = atom.workspace.getActivePaneItem()
        outline = outlineEditor.outline
        waitsForPromise ->
          expanded = [outline.getItemForID('1'), outline.getItemForID('2')]
          atom.workspace.open(outline.getFileURL(expanded: expanded)).then ->
            outlineEditor.isExpanded(outline.getItemForID('1')).should.be.ok
            outlineEditor.isExpanded(outline.getItemForID('2')).should.be.ok
            outlineEditor.isExpanded(outline.getItemForID('5')).should.not.be.ok

    it 'should apply selection to editor based on query parameter', ->
      waitsForPromise ->
        activationPromise.then ->
          atom.workspace.open(outlinePath)

      runs ->
        outlineEditor = atom.workspace.getActivePaneItem()
        outline = outlineEditor.outline
        waitsForPromise ->
          selection =
            focusItem: outline.getItemForID('4')
            focusOffset: 1
          atom.workspace.open(outline.getFileURL(selection: selection)).then ->
            outlineEditor.selection.toString().should.equal('anchor:4,1 focus:4,1')

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
