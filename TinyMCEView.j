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

    BOOL            _cursorPlaced;
    BOOL            _isTryingToBecomeFirstResponder;
    BOOL            _isEditorReady;

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

+ (void)swizzleDialogClose
{
    // Hijack the TinyMCE WindowManager's close functions so we can enable the Cappuccino eventhandling during
    // dialog sessions. Here we change the prototype close function on the WindowManager, it will then
    // apply to all instances of dialogs and windows.

    var oldCloseFunction = tinyMCE.ui.Window.prototype.close;


    var newCloseFunction = function()
    {
        // Here we enable the Cappuccino eventhandling
        [[TinyMCEViewInstance window] setIgnoresMouseEvents:NO];

        // Here we enable the Cappuccino copy and paste when the SourceCode window is closed
        [CPPlatformWindow primaryPlatformWindow]._platformPasteboard.supportsNativeCopyAndPaste = YES;

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

        // Here we disable the Cappuccino eventhandling
        [[TinyMCEViewInstance window] setIgnoresMouseEvents:YES];

        // Here we disable the Cappuccino copy and paste when the SourceCode window is open
        [CPPlatformWindow primaryPlatformWindow]._platformPasteboard.supportsNativeCopyAndPaste = NO;

        return returnValue;
    }

    tinyMCE.activeEditor.windowManager.open = newOpenFunction;
}

#pragma mark -
#pragma mark Initialization

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

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

        // Add the div to this views div element
        self._DOMElement.appendChild(_divTag);
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
    if ([self editor] == nil)
    {
        CPLog.warn(@"Can not find editor instance");
        return;
    }

    [self editor].on('click', function(e) {
        [[self window] makeFirstResponder:self];
    });

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
    editor.execCommand(editor.Command.BOLD, null);
    [self _didPerformAction];
}

- (@action)underlineSelection:(id)sender
{
    editor.execCommand(editor.Command.UNDERLINE, null);
    [self _didPerformAction];
}

- (@action)italicSelection:(id)sender
{
    editor.execCommand(editor.Command.ITALIC, null);
    [self _didPerformAction];
}

- (@action)strikethroughSelection:(id)sender
{
    editor.execCommand(editor.Command.STRIKE_THROUGH, null);
    [self _didPerformAction];
}

- (@action)alignSelectionLeft:(id)sender
{
    editor.execCommand(editor.Command.JUSTIFY_LEFT, null);
    [self _didPerformAction];
}

- (@action)alignSelectionRight:(id)sender
{
    editor.execCommand(editor.Command.JUSTIFY_RIGHT, null);
    [self _didPerformAction];
}

- (@action)alignSelectionCenter:(id)sender
{
    editor.execCommand(editor.Command.JUSTIFY_CENTER, null);
    [self _didPerformAction];
}

- (@action)alignSelectionFull:(id)sender
{
    editor.execCommand(editor.Command.JUSTIFY_FULL, null);
    [self _didPerformAction];
}

- (@action)linkSelection:(id)sender
{
    // TODO Show a sheet asking for a URL to link to.
    editor.execCommand(editor.Command.LINK, "_self");
    [self _didPerformAction];
}

- (@action)insertOrderedList:(id)sender
{
    editor.execCommand(editor.Command.ORDERED_LIST, null);
    [self _didPerformAction];
}

- (@action)insertUnorderedList:(id)sender
{
    editor.execCommand(editor.Command.UNORDERED_LIST, null);
    [self _didPerformAction];
}

- (@action)bold:(id)sender
{
    [self editor].execCommand('bold',false,null);
    [self _didPerformAction];
}

- (@action)underline:(id)sender
{
    [self editor].execCommand('underline',false,null);
    [self _didPerformAction];
}

- (@action)italic:(id)sender
{
    [self editor].execCommand('italic',false,null);
    [self _didPerformAction];
}

- (@action)strikethrough:(id)sender
{
    [self editor].execCommand('strikethrough',false,null);
    [self _didPerformAction];
}

- (@action)alignLeft:(id)sender
{
    [self editor].execCommand('justifyleft',false,null);
    [self _didPerformAction];
}

- (@action)alignRight:(id)sender
{
    [self editor].execCommand('justifyright',false,null);
    [self _didPerformAction];
}

- (@action)alignCenter:(id)sender
{
    [self editor].execCommand('justifycenter',false,null);
    [self _didPerformAction];
}

- (@action)alignFull:(id)sender
{
    [self editor].execCommand('justifyfull',false,null);
    [self _didPerformAction];
}

- (@action)header1:(id)sender
{
    [self editor].execCommand('formatblock',false,'h1');
    [self _didPerformAction];
}

- (@action)header2:(id)sender
{
    [self editor].execCommand('formatblock',false,'h1');
    [self _didPerformAction];
}

- (@action)header3:(id)sender
{
    [self editor].execCommand('formatblock',false,'h1');
    [self _didPerformAction];
}

- (@action)header4:(id)sender
{
    [self editor].execCommand('formatblock',false,'h1');
    [self _didPerformAction];
}

- (@action)header5:(id)sender
{
    [self editor].execCommand('formatblock',false,'h1');
    [self _didPerformAction];
}

- (@action)header6:(id)sender
{
    [self editor].execCommand('formatblock',false,'h1');
    [self _didPerformAction];
}

- (void)header:(CPString)header
{
    [self editor].execCommand('formatblock',false,header);
    [self _didPerformAction];
}

- (void)superscript:(CPString)header
{
    [self editor].execCommand('superscript',false,null);
    [self _didPerformAction];
}

- (void)subscript:(CPString)header
{
    [self editor].execCommand('subscript',false,null);
    [self _didPerformAction];
}

- (@action)removeFormat:(id)sender
{
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
    [self _didBeginEditing];
    var theEditor = [self editor];
    if (theEditor != nil)
    {
        if (_cursorPlaced)
        {
            theEditor.focus();
        }
        else
        {
            theEditor.focus();
            _cursorPlaced = YES;
        }
    }

    [self _pumpRunLoop];

    return YES;
}

- (BOOL)resignFirstResponder
{
    var win = [self window];

    if (win == nil)
        return NO;

    win._DOMElement.focus();
    [self _didEndEditing];

    return YES;
}

- (BOOL)tryToBecomeFirstResponder
{
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

        if (theEditor)
        {
            _html = theEditor.getContent();
            _innerText = theEditor.contentDocument.activeElement.innerText;
            tinyMCEManager.remove([self editor]);
            editor = nil;
        }
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
    var theEditor = [self editor];

    if (!theEditor)
        return _html;

    var content = theEditor.getContent();

    return content;
}

/*!
 Sets the html the view should handle.
 */
- (void)setHtmlValue:(CPString)html
{
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
    var theEditor = [self editor];

    if (!theEditor)
        return _innerText;

    var content = theEditor.contentDocument.activeElement.innerText;

    return content;
}


#pragma mark -
#pragma mark Delegation handling

- (void)_didChange
{
    // When the text changes, the height of the content may change.
    if ([delegate respondsToSelector:@selector(editorViewDidChange:)])
        [delegate editorViewDidChange:self];
}

- (void)_didBeginEditing
{
    if ([delegate respondsToSelector:@selector(editorViewDidBeginEditing:)])
        [delegate editorViewDidBeginEditing:self];
}

- (void)_didEndEditing
{
    if ([delegate respondsToSelector:@selector(editorViewDidEndEditing:)])
        [delegate editorViewDidEndEditing:self];
}

#pragma mark -
#pragma mark Resizeing

- (void)layoutSubviews
{
    [super layoutSubviews];

    var theEditor = [self editor];

    try {
        if (theEditor)
        {
            // If we have a toolbar we have to remove it from the total height of the view

            var frameWidth = [self frame].size.width,
                frameHeight = [self frame].size.height,
                offset = [self subcomponentsOffset];

            theEditor.theme.resizeTo(frameWidth - 3, frameHeight - offset - 3);
        }
    }
    catch (exception) {
        var frameWidth = [self frame].size.width,
            frameHeight = [self frame].size.height,
            offset = [self subcomponentsOffset];

        CPLog.warn(_cmd + " " + [self class] + @"Can not resize - frameWidth " + frameWidth + @" frameHeight " + frameHeight + @" offset " + offset);
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
    [[[anEvent window] platformWindow] _propagateCurrentDOMEvent:YES];
}

- (void)mouseUp:(CPEvent)anEvent
{
    [[[anEvent window] platformWindow] _propagateCurrentDOMEvent:YES];
}

- (void)mouseDragged:(CPEvent)anEvent
{
    [[[anEvent window] platformWindow] _propagateCurrentDOMEvent:YES];
}

- (void)keyDown:(CPEvent)anEvent
{
    [[[anEvent window] platformWindow] _propagateCurrentDOMEvent:YES];
}

- (void)keyUp:(CPEvent)anEvent
{
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
