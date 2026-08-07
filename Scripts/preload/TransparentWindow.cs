// Remember to include System and System.Runtime.InteropServices


// thank you ZeadenTheBirb for adding linux support to this
using Godot;
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public partial class TransparentWindow : Node
{ // Autoloaded

    // SetWindowLong() modifies a specific flag value associated with a window.
    // We pass the window handle, the index of the property, and the flags the property will have
    [DllImport("user32.dll")]
    private static extern int SetWindowLong(IntPtr hWnd, int nIndex, uint dwNewLong);

    // This is the index of the property we want to modify
    private const int GwlExStyle = -20;

    // The flags we want to set
    private const int WsExLayered = 0x80000;         // Makes the window "layered"
    private const int WsExTransparent = 0x20;       // Makes the window "clickable through"
                                                    // check https://learn.microsoft.com/en-us/windows/win32/winmsg/extended-window-styles 
                                                    // This is the variable containing the window handle

    [StructLayout(LayoutKind.Sequential)]
    private struct XRectangle
    {
        public short X;
        public short Y;
        public ushort Width;
        public ushort Height;
    }

    [DllImport("libXext.so.6", CallingConvention = CallingConvention.Cdecl)]
    private static extern int XShapeQueryExtension(IntPtr display, out int eventBase, out int errorBase);

    [DllImport("libXext.so.6", CallingConvention = CallingConvention.Cdecl)]
    private static extern void XShapeCombineRectangles(
        IntPtr display,
        nuint destinationWindow,
        int destinationKind,
        int xOffset,
        int yOffset,
        [In] XRectangle[] rectangles,
        int rectangleCount,
        int operation,
        int ordering);

    [DllImport("libX11.so.6", CallingConvention = CallingConvention.Cdecl)]
    private static extern int XFlush(IntPtr display);

    private const int ShapeInput = 2;
    private const int ShapeSet = 0;
    private const int Unsorted = 0;

    private IntPtr _hWnd;
    //  private bool isGb;

    private bool _isWindows;
    private bool _isX11;
    private bool _xShapeAvailable;
    private IntPtr _xDisplay = IntPtr.Zero;
    private nuint _xWindow;

    private readonly Dictionary<long, Rect2I> _inputRects = new();
    private bool _inputRectsDirty;

    public override void _Ready()
    {
        _isWindows = OperatingSystem.IsWindows();
        _isX11 = OperatingSystem.IsLinux() && DisplayServer.GetName() == "X11";

        GetWindow().Transparent = true;
        GetWindow().TransparentBg = true;

        if (_isWindows)
        {
            // We store the window handle
            _hWnd = (IntPtr)DisplayServer.WindowGetNativeHandle(DisplayServer.HandleType.WindowHandle, GetWindow().GetWindowId());

            SetWindowLong(_hWnd, GwlExStyle, WsExLayered);
            SetClickThrough(true);
            return;
        }

        if (_isX11)
        {
            InitX11InputRegions();
            Engine.MaxFps = 45;
            return;
        }

        GetWindow().MousePassthrough = true;
        Engine.MaxFps = 45;
    }

    public override void _Process(double _delta)
    {
        if (UsesInputRegions() && _inputRectsDirty)
        {
            ApplyX11InputRegion();
        }
    }

    public bool UsesInputRegions()
    {
        return _isX11 && _xShapeAvailable;
    }

    private void InitX11InputRegions()
    {
        try
        {
            long displayHandle = DisplayServer.WindowGetNativeHandle(DisplayServer.HandleType.DisplayHandle, GetWindow().GetWindowId());

            long windowHandle = DisplayServer.WindowGetNativeHandle(DisplayServer.HandleType.WindowHandle, GetWindow().GetWindowId());

            _xDisplay = new IntPtr(displayHandle);
            _xWindow = unchecked((nuint)windowHandle);

            if (_xDisplay == IntPtr.Zero || _xWindow == 0)
            {
                GD.PushWarning("DeskSaw: Could not get X11 display/window handles. Falling back to Godot mouse passthrough.");
                GetWindow().MousePassthrough = true;
                return;
            }

            if (XShapeQueryExtension(_xDisplay, out _, out _) == 0)
            {
                GD.PushWarning("DeskSaw: XShape is not available. Falling back to Godot mouse passthrough.");
                GetWindow().MousePassthrough = true;
                return;
            }

            _xShapeAvailable = true;
            GetWindow().MousePassthrough = false;

            _inputRectsDirty = true;
            ApplyX11InputRegion();
        }
        catch (DllNotFoundException e)
        {
            GD.PushWarning($"DeskSaw: X11 input-region library missing: {e.Message}");
            GetWindow().MousePassthrough = true;
        }
        catch (EntryPointNotFoundException e)
        {
            GD.PushWarning($"DeskSaw: X11 input-region function missing: {e.Message}");
            GetWindow().MousePassthrough = true;
        }
    }

    public void SetInputRect(long id, Rect2 rect, bool enabled)
    {
        if (!UsesInputRegions())
        {
            return;
        }

        if (!enabled || rect.Size.X <= 0.0f || rect.Size.Y <= 0.0f)
        {
            RemoveInputRect(id);
            return;
        }

        int x1 = (int)Math.Floor(rect.Position.X);
        int y1 = (int)Math.Floor(rect.Position.Y);
        int x2 = (int)Math.Ceiling(rect.End.X);
        int y2 = (int)Math.Ceiling(rect.End.Y);

        var pixelRect = new Rect2I(x1, y1, x2 - x1, y2 - y1);
        if (pixelRect.Size.X <= 0 || pixelRect.Size.Y <= 0)
        {
            RemoveInputRect(id);
            return;
        }

        if (_inputRects.TryGetValue(id, out Rect2I oldRect) && oldRect == pixelRect)
        {
            return;
        }

        _inputRects[id] = pixelRect;
        _inputRectsDirty = true;
    }

    public void RemoveInputRect(long id)
    {
        if (!UsesInputRegions())
        {
            return;
        }

        if (_inputRects.Remove(id))
        {
            _inputRectsDirty = true;
        }
    }

    private void ApplyX11InputRegion()
    {
        if (!UsesInputRegions() || _xDisplay == IntPtr.Zero || _xWindow == 0)
        {
            return;
        }

        Vector2I windowSize = GetWindow().Size;
        int windowWidth = Math.Max(windowSize.X, 0);
        int windowHeight = Math.Max(windowSize.Y, 0);

        var rectangles = new List<XRectangle>(_inputRects.Count);

        foreach (Rect2I rect in _inputRects.Values)
        {
            int x1 = Math.Clamp(rect.Position.X, 0, Math.Min(windowWidth, short.MaxValue));
            int y1 = Math.Clamp(rect.Position.Y, 0, Math.Min(windowHeight, short.MaxValue));
            int x2 = Math.Clamp(rect.End.X, 0, windowWidth);
            int y2 = Math.Clamp(rect.End.Y, 0, windowHeight);

            int width = Math.Min(x2 - x1, ushort.MaxValue);
            int height = Math.Min(y2 - y1, ushort.MaxValue);
            if (width <= 0 || height <= 0)
            {
                continue;
            }

            rectangles.Add(new XRectangle
            {
                X = (short)x1,
                Y = (short)y1,
                Width = (ushort)width,
                Height = (ushort)height
            });
        }

        XRectangle[] nativeRectangles = rectangles.ToArray();

        XShapeCombineRectangles(
            _xDisplay,
            _xWindow,
            ShapeInput,
            0,
            0,
            nativeRectangles,
            nativeRectangles.Length,
            ShapeSet,
            Unsorted);

        XFlush(_xDisplay);
        _inputRectsDirty = false;
    }

    // This function sets the property of being clickable or not.
    public void SetClickThrough(bool clickthrough)
    {
        if (_isWindows)
        {
            if (clickthrough)
            {
                SetWindowLong(_hWnd, GwlExStyle, WsExLayered | WsExTransparent);
                Engine.MaxFps = 45;
            }
            else
            {
                SetWindowLong(_hWnd, GwlExStyle, WsExLayered);
                Engine.MaxFps = 60;
            }

            return;
        }

        if (UsesInputRegions())
        {
            Engine.MaxFps = clickthrough ? 45 : 60;
            return;
        }

        GetWindow().MousePassthrough = clickthrough;
        Engine.MaxFps = clickthrough ? 45 : 60;
    }

    /* What is a layered window? 
	 * In the Windows API, a layered window is a special type of window that offers several
	 * advantages over standard windows:
	 * 
	 * Transparency: Layered windows can be partially transparent, allowing the content of underlying windows
	 * to show through. This can be achieved using either color keying, where a specific color in the window
	 * is transparent, or alpha blending, where the window's opacity is specified for each pixel.
	 *
	 * Complex Shapes: Layered windows can have complex shapes that are not limited by rectangular regions.
	 * This is achieved by defining a custom region, allowing for more visually appealing or functional window designs.
	 *
	 * Animation: Layered windows can be animated smoothly without the visual artifacts
	 * that can occur with standard windows due to region updates. This is because the system automatically manages
	 * the composition of layered windows with underlying elements.
	 */
}