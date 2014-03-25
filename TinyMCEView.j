/*
 *  TinyMCEView.j
 *  TinyMCEView
 *
 *  Created by Kjell Nilsson, Oops ab on 2014-01-17.
 */

@import <Foundation/Foundation.j>
@import <AppKit/CPView.j>

var TinyMCEditorManager,
    TinyMCEViewInstance;

@implementation TinyMCEView : CPView
{
    JSObject        editor;
    @outlet id      delegate @accessors;

    BOOL            editable;
    BOOL            enabled;

    BOOL            shouldFocusAfterAction;

    boolean         _cursorPlaced;
    boolean         _isTryingToBecomeFirstResponder;
    boolean         _isEditorReady;

    CPString        _html;
    CPString        _innerText;
    JSObject        _divTag;

    JSObject        imageListItems;
    JSObject        linkListItems;
}

#pragma mark -
#pragma mark Class

+ (void)initialize
{
    //CPLog.trace(_cmd + " " + [self class] +  " ");

    [TinyMCEView swizzleDialogClose];
}

+ (JSObject)TinyMCE
{
    return tinyMCE;
}

+ (JSObject)TinyMCEditorManager
{
    return tinyMCE.EditorManager;
}

// Mouse events gets propagated through to the underlying Cappucino controls when click is happening
// outside of the TinyMCE view and we have to prevent this from happening since unwanted event might
// occur. We do this by swizzle the functions 'open' and 'close' window in TinyMCE.
// One problem still exist in this version and that is menus, if they displays outside of the TinyMCE
// editor frame the mouse clicks propagates through to the underlying Cappuccino view.

+ (void)swizzleDialogClose
{
    // Hijack the TinyMCE WindowManager's close functions so we can enable the Cappuccino eventhandling during
    // dialog sessions. Here we change the prototype close function on the WindowManager, it will then
    // apply to all instances of dialogs and windows.

    var oldCloseFunction = tinyMCE.ui.Window.prototype.close;

    var newCloseFunction = function()
    {
        //CPLog.trace("Hijacked closed " + TinyMCEViewInstance);

        // Here we enable the Cappuccino eventhandling
        [[TinyMCEViewInstance window] setIgnoresMouseEvents:NO];

        return oldCloseFunction.apply(this, arguments);
    }

    tinyMCE.ui.Window.prototype.close = newCloseFunction;
}

+ (void)swizzleDialogOpenWithInstance:(TinyMCEView)view
{
    // Hijack the TinyMCE WindowManager's open functions so we can disable the Cappuccino eventhandling during
    // the dialog session. The open function on the windowManager is created on each instance so we have
    // to do it each time we create an instace.

    var oldOpenFunction = tinyMCE.activeEditor.windowManager.open;

    TinyMCEViewInstance = view;

    var newOpenFunction = function()
    {
        var returnValue = oldOpenFunction.apply(this, arguments);

        //CPLog.trace("Hijacked open " + TinyMCEViewInstance);

        // Here we disable the Cappuccino eventhandling
        [[TinyMCEViewInstance window] setIgnoresMouseEvents:YES];

        return returnValue;
    }

    tinyMCE.activeEditor.windowManager.open = newOpenFunction;
}

#pragma mark -
#pragma mark Initialization

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    //CPLog.trace(_cmd + " " + [self class]);
    if (self)
    {
        // Set the instance variables
        shouldFocusAfterAction = YES;
        editable = YES;
        enabled = YES;
        _html = nil;
        _innerText = nil;
        imageListItems = [CPArray array];
        linkListItems = [CPArray array];

        _cursorPlaced = NO;
        _isEditorReady = NO;

        // Create a div element that the editor will operate on, set its id and classname
        _divTag = document.createElement("div");
        _divTag.id = [self _editorId];
        _divTag.className = [self _divTagClassName];

#if PLATFORM(DOM)
        // Add the div to this views div element
        _DOMElement.appendChild(_divTag);
#endif
    }

    return self;
}

/*
 This method creates the TinyMCE editor instance and concludes the setup after a performed delay. 
 Since the TinyMCE editor instans runs with a nother eventhandling the delayed perfor is needed 
 so the editor can run its setup using its eventhandling.
 To find out if editor is ready for use, call the method isEditorReady.
 */
- (void)doSetupWithDiv
{
    //CPLog.trace(_cmd + " " + [self class] +  " ");

    _isEditorReady = NO;

    // Create and configure the editor instance
    var tinyMCE = [TinyMCEView TinyMCE],
        tinyMCEManager = [TinyMCEView TinyMCEditorManager],

    // Configure the editor
        configuration = [self editorConfigurationWithElement:_divTag];

    tinyMCEManager.init(configuration);
}

/*!
 This method creates the TinyMCE editor configuration. Returns a JavaScript object containing the
 configuration parameters. For a custom configuration subclass the TinyNCEView and overide this
 method.
 */
- (JSObject)editorConfigurationWithElement:(JSObject)anElement
{
    //CPLog.trace(_cmd + " " + [self class]);

    return {
    setup:
        function(anEditor)
        {
            // When the editor is initialized it sends an event In this event we can conclude the views
            // setup and set up other dom events.
            anEditor.on('init',
                function(e)
                {
                    [self concludeSetup];
                    anEditor.dom.bind(anEditor.getWin(), 'resize',
                        function()
                        {
                            // There is a situation when resizing the window with a TinyMCEView the view
                            // does not get redrawn properly. This call to layoutSubviews fixes this.
                            [self layoutSubviews];
                        }
                    );
                }
            );
        },

    selector: @"div." + anElement.className,
    width: [self frame].size.width - 3,
    height: [self frame].size.height - 3,
    theme: "modern",
    language: "sv_SE",
        mode : "exact",
    statusbar: YES,
    menubar: YES,
    resize: false,
    toolbar: "insertfile undo redo | styleselect | bold italic | alignleft aligncenter alignright alignjustify | bullist numlist outdent indent | link image",
    image_list: imageListItems,
    link_list: linkListItems,
    plugins: [
              "advlist lists link image charmap print preview hr anchor pagebreak",
              "searchreplace visualblocks visualchars code",
              "insertdatetime nonbreaking table contextmenu"
              ]
    };
}

// This method concludes the setup. It waits for the editor manager to fullfill the isEditorReady creation
- (void)concludeSetup
{
    //CPLog.trace(_cmd + " " + [self class]);

    if ([self editor] == nil)
    {
        CPLog.warn(@"Can not find editor instance");
        return;
    }

    [self editor].on('focus', function(e) {
        //console.log("focus " + e.blurredEditor);
    });

    [self editor].on('blur', function(e) {
        //console.log("blur " + e.focusedEditor);
    });

    [self editor].on('click', function(e) {
        //console.log("click " + e.focusedEditor);
        [[self window] makeFirstResponder:self];
    });

    // TODO: Check this out what to use
    // 1)[self performSelector:@selector(layoutSubviews) withObject:nil afterDelay:0.0];
    // 2)[self _pumpRunLoop];
    // 3)
    [self layoutSubviews];

    _isEditorReady = YES;

    if (_html)
        [self setHtmlValue:_html];

    if ([delegate respondsToSelector:@selector(editorViewDidConcludeSetup:)])
        [delegate editorViewDidConcludeSetup:self];

    [TinyMCEView swizzleDialogOpenWithInstance:self];
}


#pragma mark -
#pragma mark Actions

- (@action)clearText:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self setHtmlValue:""];
    [self _didChange];
    [self _didPerformAction];
}

- (void)insertHtml:(CPString)html
{
    [self editor].execCommand('mceInsertContent',false, html);
    [self _didChange];
    [self _didPerformAction];
}

- (@action)boldSelection:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    editor.execCommand(editor.Command.BOLD, null);
    [self _didPerformAction];
}

- (@action)underlineSelection:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    editor.execCommand(editor.Command.UNDERLINE, null);
    [self _didPerformAction];
}

- (@action)italicSelection:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    editor.execCommand(editor.Command.ITALIC, null);
    [self _didPerformAction];
}

- (@action)strikethroughSelection:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    editor.execCommand(editor.Command.STRIKE_THROUGH, null);
    [self _didPerformAction];
}

- (@action)alignSelectionLeft:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    editor.execCommand(editor.Command.JUSTIFY_LEFT, null);
    [self _didPerformAction];
}

- (@action)alignSelectionRight:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    editor.execCommand(editor.Command.JUSTIFY_RIGHT, null);
    [self _didPerformAction];
}

- (@action)alignSelectionCenter:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    editor.execCommand(editor.Command.JUSTIFY_CENTER, null);
    [self _didPerformAction];
}

- (@action)alignSelectionFull:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    editor.execCommand(editor.Command.JUSTIFY_FULL, null);
    [self _didPerformAction];
}

- (@action)linkSelection:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    // TODO Show a sheet asking for a URL to link to.
    editor.execCommand(editor.Command.LINK, "_self");
    [self _didPerformAction];
}

- (@action)insertOrderedList:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    editor.execCommand(editor.Command.ORDERED_LIST, null);
    [self _didPerformAction];
}

- (@action)insertUnorderedList:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    editor.execCommand(editor.Command.UNORDERED_LIST, null);
    [self _didPerformAction];
}

- (@action)bold:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('bold',false,null);
    [self _didPerformAction];
}

- (@action)underline:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('underline',false,null);
    [self _didPerformAction];
}

- (@action)italic:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('italic',false,null);
    [self _didPerformAction];
}

- (@action)strikethrough:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('strikethrough',false,null);
    [self _didPerformAction];
}

- (@action)alignLeft:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('justifyleft',false,null);
    [self _didPerformAction];
}

- (@action)alignRight:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('justifyright',false,null);
    [self _didPerformAction];
}

- (@action)alignCenter:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('justifycenter',false,null);
    [self _didPerformAction];
}

- (@action)alignFull:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('justifyfull',false,null);
    [self _didPerformAction];
}

- (@action)header1:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('formatblock',false,'h1');
    [self _didPerformAction];
}

- (@action)header2:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('formatblock',false,'h1');
    [self _didPerformAction];
}

- (@action)header3:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('formatblock',false,'h1');
    [self _didPerformAction];
}

- (@action)header4:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('formatblock',false,'h1');
    [self _didPerformAction];
}

- (@action)header5:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('formatblock',false,'h1');
    [self _didPerformAction];
}

- (@action)header6:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('formatblock',false,'h1');
    [self _didPerformAction];
}

- (void)header:(CPString)header
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('formatblock',false,header);
    [self _didPerformAction];
}

- (void)superscript:(CPString)header
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('superscript',false,null);
    [self _didPerformAction];
}

- (void)subscript:(CPString)header
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('subscript',false,null);
    [self _didPerformAction];
}

- (@action)removeFormat:(id)sender
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self editor].execCommand('removeFormat');
    [self _didPerformAction];
}

#pragma mark -
#pragma mark FirstResponder

- (BOOL)acceptsFirstResponder
{
    return [self isEditable] && [self isEnabled];
}

- (BOOL)becomeFirstResponder
{
    //CPLog.trace(_cmd + " " + [self class]);
    [self _didBeginEditing];
    var theEditor = [self editor];
    if (theEditor != nil)
    {
        if (_cursorPlaced)
        {
            //CPLog.trace(@"Become focus " + theEditor);
            theEditor.focus();
        }
        else
        {
            theEditor.focus();
            _cursorPlaced = YES;
        }
    }

    //[self performSelector:@selector(layoutSubviews) withObject:nil afterDelay:0.8];
    [self _pumpRunLoop];

    return YES;
}

- (BOOL)resignFirstResponder
{
    //CPLog.trace(_cmd + " " + [self class]);
    var win = [self window];

    if (win == nil)
        return NO;

    win._DOMElement.focus();
    [self _didEndEditing];

    return YES;
}

- (BOOL)tryToBecomeFirstResponder
{
    //CPLog.trace(_cmd + " " + [self class]);
    if (_isTryingToBecomeFirstResponder)
        return YES;

    var win = [self window];

    if (win == nil)
        return NO;

    if ([win firstResponder] === self)
        return YES;

    // We have to emulate select pieces of CPWindow's event handling
    // here since the iframe bypasses the regular event handling.
    var becameFirst = false;

    _isTryingToBecomeFirstResponder = YES;
    try
    {
        if ([self acceptsFirstResponder])
        {
            becameFirst = [win makeFirstResponder:self];
            if (becameFirst)
            {
                if (![win isKeyWindow])
                    [win makeKeyAndOrderFront:self];
                [self _pumpRunLoop];
            }
        }
    }
    finally
    {
        _isTryingToBecomeFirstResponder = NO;
    }

    return becameFirst;
}


#pragma mark -
#pragma mark Getter & Setter

- (JSObject)editor
{
    // editor can never be active while hidden.
    var manager = [TinyMCEView TinyMCEditorManager];
    var ed = nil,
        eid = [self _editorId];

    ed = manager.get(eid);

    if (editor == nil && ed != nil)
        editor = ed;

    var theEditor = [self isHiddenOrHasHiddenAncestor] ? nil : editor;
    //CPLog.trace(_cmd + " " + [self class] + " " + theEditor);

    return theEditor;
}

- (CPArray)imageListItems
{
    return imageListItems;
}

- (CPArray)linkListItems
{
    return linkListItems;
}

- (BOOL)isEditorReady
{
    return _isEditorReady;
}

/*!
 Sets whether the receiver should be hidden.
 Since TinyMCE uses an iframe when active and most browsers forgets everything about the ifram when
 the iframe is removed from the DOM tree, the editor must be removed and recreated when it is 
 hidden/unhidden. Use this method when for example when a superview gets switched out an in.
 @param shouldBeHidden \c YES makes the receiver hidden.
 */
- (void)setHidden:(BOOL)shouldBeHidden
{
    // TODO: Remove the tinyMCEditor editor from the view if the view gets hidden
    //      and create a new when it gets unhidden again.

    if (shouldBeHidden)
    {
        var tinyMCE = [TinyMCEView TinyMCE],
            tinyMCEManager = [TinyMCEView TinyMCEditorManager],
            theEditor = [self editor];

        _html = theEditor.getContent();
        _innerText = theEditor.contentDocument.activeElement.innerText;
        tinyMCEManager.remove([self editor]);
        editor = nil;
        _isEditorReady = NO;

        [super setHidden:shouldBeHidden];
    }
    else
    {
        [super setHidden:shouldBeHidden];

        // Since the browser has to do some housekeeping with the dom tree the tinyMCE editor
        // setup has to be performed delayed. This also makes it posible to reconfigure the editor
        // before it gets displayed.

        [self performSelector:@selector(doSetupWithDiv) withObject:nil afterDelay:0.0];
        //[self doSetupWithDiv];
    }
}

- (void)viewWillMoveToWindow:(CPWindow)newWindow
{
    [super viewWillMoveToWindow:newWindow];

    if (_window)
    {
        //CPLog.trace(@"View did move to window");
    }
    else
    {
        //CPLog.trace(@"View did move from window");
    }
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];

    if (_window)
    {
        //CPLog.trace(@"View did move to window");
    }
    else
    {
        //CPLog.trace(@"View did move from window");
    }
}

/*!
 Returns \c YES if the receiver is hidden.
 */
- (BOOL)isHidden
{
    return [super isHidden];
}

/*!
 Sets whether or not the receiver text view can be edited.
 */
- (void)setEditable:(BOOL)shouldBeEditable
{
    editable = shouldBeEditable;
}

/*!
 Returns \c YES if the text view is currently editable by the user.
 */
- (BOOL)isEditable
{
    return editable;
}

/*!
 Sets the enabled status of the view.
 Controls that are not enabled can not be changed by the user ( TODO: and obtain the CPThemeStateDisabled theme state).
 
 @param BOOL - YES if the view should be enabled, otherwise NO.
 */
- (void)setEnabled:(BOOL)shouldBeEnabled
{
    if (enabled === shouldBeEnabled)
        return;

    enabled = shouldBeEnabled;

    [self _actualizeEnabledState];
}

- (void)_actualizeEnabledState
{
    if ([self editor])
    {
        //CPLog.trace(_cmd + " " + [self class] + " " + [self editor].id);

        [self editor].focus();
        var isEnabled = ![self editor].isHidden();
        if (!isEnabled && enabled)
            [self editor].show();
        else if (isEnabled && !enabled)
            [self editor].hide();
        [self _pumpRunLoop];
    }
}

/*!
 Returns \c YES if the text view is currently editable by the user.
 */
- (BOOL)isEnabled
{
    return enabled;
}

/*!
 Returns \c YES if the  view should focus the editor after an action has 
 been invoked.
 */
- (BOOL)shouldFocusAfterAction
{
    return shouldFocusAfterAction;
}

/*!
 Sets whether the editor should automatically take focus after an action
 method is invoked such as boldSelection or setFont. This is useful for
 instance when binding actions from an external toolbar.
 */
- (void)setShouldFocusAfterAction:(BOOL)aFlag
{
    shouldFocusAfterAction = aFlag;
}

/*!
 Returns the  html the view handles.
 */
- (CPString)htmlValue
{
    //CPLog.trace(_cmd + " " + [self class]);
    var theEditor = [self editor];

    if (!theEditor)
        return _html;

    var content = theEditor.getContent();

    //CPLog.trace(_cmd + " " + [self class] + " :" + content);

    return content;
}

/*!
 Sets the html the view should handle.
 */
- (void)setHtmlValue:(CPString)html
{
    //CPLog.trace(_cmd + " " + [self class]);

    var theEditor = [self editor];

    if (theEditor != nil && _isEditorReady)
    {
        if (html == nil)
            html = @"";
        theEditor.setContent(html);
    }
    else
    {
        _html = html;
    }

    _cursorPlaced = NO;
    [self _didChange];
}

/*!
 Returns a string value from the  view. (Test implementation)
 */
- (CPString)stringValue
{
    //CPLog.trace(_cmd + " " + [self class]);

    var theEditor = [self editor];

    if (!theEditor)
        return _innerText;

    var content = theEditor.contentDocument.activeElement.innerText;

    //CPLog.trace(_cmd + " " + [self class] + " :" + content);

    return content;
}


#pragma mark -
#pragma mark Delegation handling

- (void)_didChange
{
    //CPLog.trace(_cmd + " " + [self class]);
    // When the text changes, the height of the content may change.
    if ([delegate respondsToSelector:@selector(editorViewDidChange:)])
        [delegate editorViewDidChange:self];
}

- (void)_didBeginEditing
{
    //CPLog.trace(_cmd + " " + [self class]);
    if ([delegate respondsToSelector:@selector(editorViewDidBeginEditing:)])
        [delegate editorViewDidBeginEditing:self];
}

- (void)_didEndEditing
{
    //CPLog.trace(_cmd + " " + [self class]);
    if ([delegate respondsToSelector:@selector(editorViewDidEndEditing:)])
        [delegate editorViewDidEndEditing:self];
}

#pragma mark -
#pragma mark Resizeing

- (void)layoutSubviews
{
    //CPLog.trace(_cmd + " " + [self class]);
    [super layoutSubviews];

    var theEditor = [self editor];
    //CPLog.trace(@"layoutSubviews editor" + theEditor);

    try {
        if (theEditor)
        {
            // If we have a toolbar we have to remove it from the total height of the view

            var frameWidth = [self frame].size.width,
                frameHeight = [self frame].size.height,
                offset = [self subcomponentsOffset];

            //CPLog.trace(_cmd + " " + [self class] + @" offset " + offset);
            theEditor.theme.resizeTo(frameWidth - 3, frameHeight - offset - 3);
        }
    }
    catch (exception) {
        //CPLog.trace(_cmd + " " + [self class] + @" Can not resize");
        var frameWidth = [self frame].size.width,
            frameHeight = [self frame].size.height,
            offset = [self subcomponentsOffset];

        CPLog.warn(_cmd + " " + [self class] + @" frameWidth " + frameWidth + @" frameHeight " + frameHeight + @" offset " + offset);
    }
}

- (float)subcomponentsOffset
{
    var theEditor = [self editor];

    if (theEditor)
    {
        // If we have a toolbar we have to remove it from the total height of the view

        var container = theEditor.getContainer(),
            offset = 0;

        for (var i = 0; i < container.children[0].children.length; i++)
        {
            var editorComponent = container.children[0].children[i],
                editorComponentClassName = editorComponent.className;

            if (![editorComponentClassName hasPrefix:@"mce-edit-area"])
            {
                offset += editorComponent.offsetHeight;
            }
        }
        return offset;
    }
    return 0;
}

#pragma mark -
#pragma mark Event propagation

// TODO: Check this out if needed
- (void)mouseDown:(CPEvent)anEvent
{
    //CPLog.trace(_cmd + " " + [self class]);
    [[[anEvent window] platformWindow] _propagateCurrentDOMEvent:YES];
}

- (void)mouseUp:(CPEvent)anEvent
{
    //CPLog.trace(_cmd + " " + [self class]);
    [[[anEvent window] platformWindow] _propagateCurrentDOMEvent:YES];
}

- (void)mouseDragged:(CPEvent)anEvent
{
    //CPLog.trace(_cmd + " " + [self class]);
    [[[anEvent window] platformWindow] _propagateCurrentDOMEvent:YES];
}

- (void)keyDown:(CPEvent)anEvent
{
    //CPLog.trace(_cmd + " " + [self class]);
    [[[anEvent window] platformWindow] _propagateCurrentDOMEvent:YES];
}

- (void)keyUp:(CPEvent)anEvent
{
    //CPLog.trace(_cmd + " " + [self class]);
    [[[anEvent window] platformWindow] _propagateCurrentDOMEvent:YES];
}


#pragma mark -
#pragma mark Private methods

- (void)_pumpRunLoop
{
    // Pump the run loop, TinyMCE event handlers are called outside of Cappuccino's run loop
    [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
}

- (CPString)_editorId
{
    // Return a default name.
    return @"TMCE-" + [self UID];
}

- (CPString)_divTagClassName
{
    // Return a default name.
    return @"editable";
}

- (void)_didPerformAction
{
    //CPLog.trace(_cmd + " " + [self class]);

    if (shouldFocusAfterAction)
    {
        var win = [self window];

        if (win == nil)
            return;

        win._DOMElement.focus();
        [self editor].focus();
    }
}

@end
