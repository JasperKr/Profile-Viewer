local ffi = require("ffi")

-- set imgui style --
local imgui = Imgui
local style = imgui.style

style.WindowRounding = 2
style.WindowBorderSize = 0
style.FrameBorderSize = 0
style.FrameRounding = 2
style.ChildRounding = 2
style.PopupRounding = 2


local ImVec4 = Imgui.ImVec4_Float
local colors = style.Colors;


colors[imgui.ImGuiCol_Text]                      = ImVec4(1.00, 1.00, 1.00, 0.90);
colors[imgui.ImGuiCol_TextDisabled]              = ImVec4(0.50, 0.50, 0.50, 0.98);
colors[imgui.ImGuiCol_WindowBg]                  = ImVec4(0.13, 0.13, 0.13, 0.98);
colors[imgui.ImGuiCol_ChildBg]                   = ImVec4(0.00, 0.00, 0.00, 0.00);
colors[imgui.ImGuiCol_PopupBg]                   = ImVec4(0.13, 0.13, 0.13, 0.98);
colors[imgui.ImGuiCol_Border]                    = ImVec4(0.59, 0.55, 0.47, 1.00);
colors[imgui.ImGuiCol_BorderShadow]              = ImVec4(0.51, 0.47, 0.41, 1.00);
colors[imgui.ImGuiCol_FrameBg]                   = ImVec4(1.00, 1.00, 1.00, 0.02);
colors[imgui.ImGuiCol_FrameBgHovered]            = ImVec4(0.25, 0.25, 0.25, 0.98);
colors[imgui.ImGuiCol_FrameBgActive]             = ImVec4(0.98, 0.98, 0.98, 0.67);
colors[imgui.ImGuiCol_TitleBg]                   = ImVec4(0.25, 0.25, 0.25, 0.98);
colors[imgui.ImGuiCol_TitleBgActive]             = ImVec4(0.25, 0.25, 0.25, 0.98);
colors[imgui.ImGuiCol_TitleBgCollapsed]          = ImVec4(0.25, 0.25, 0.25, 0.98);
colors[imgui.ImGuiCol_MenuBarBg]                 = ImVec4(0.14, 0.14, 0.14, 1.00);
colors[imgui.ImGuiCol_ScrollbarBg]               = ImVec4(0.25, 0.25, 0.25, 0.98);
colors[imgui.ImGuiCol_ScrollbarGrab]             = ImVec4(1.00, 1.00, 1.00, 0.29);
colors[imgui.ImGuiCol_ScrollbarGrabHovered]      = ImVec4(0.40, 0.40, 0.40, 0.98);
colors[imgui.ImGuiCol_ScrollbarGrabActive]       = ImVec4(0.50, 0.50, 0.50, 0.98);
colors[imgui.ImGuiCol_CheckMark]                 = ImVec4(1.00, 1.00, 1.00, 0.39);
colors[imgui.ImGuiCol_SliderGrab]                = ImVec4(0.50, 0.50, 0.50, 0.98);
colors[imgui.ImGuiCol_SliderGrabActive]          = ImVec4(0.40, 0.40, 0.40, 0.98);
colors[imgui.ImGuiCol_Button]                    = ImVec4(0.25, 0.25, 0.25, 0.98);
colors[imgui.ImGuiCol_ButtonHovered]             = ImVec4(0.75, 0.75, 0.75, 0.98);
colors[imgui.ImGuiCol_ButtonActive]              = ImVec4(0.50, 0.50, 0.50, 0.98);
colors[imgui.ImGuiCol_Header]                    = ImVec4(0.25, 0.25, 0.25, 0.98);
colors[imgui.ImGuiCol_HeaderHovered]             = ImVec4(0.75, 0.75, 0.75, 0.98);
colors[imgui.ImGuiCol_HeaderActive]              = ImVec4(0.50, 0.50, 0.50, 0.98);
colors[imgui.ImGuiCol_Separator]                 = ImVec4(0.50, 0.50, 0.50, 0.50);
colors[imgui.ImGuiCol_SeparatorHovered]          = ImVec4(0.75, 0.75, 0.75, 0.78);
colors[imgui.ImGuiCol_SeparatorActive]           = ImVec4(0.75, 0.75, 0.75, 1.00);
colors[imgui.ImGuiCol_ResizeGrip]                = ImVec4(0.50, 0.50, 0.50, 0.98);
colors[imgui.ImGuiCol_ResizeGripHovered]         = ImVec4(0.40, 0.40, 0.40, 0.98);
colors[imgui.ImGuiCol_ResizeGripActive]          = ImVec4(0.50, 0.50, 0.50, 0.98);
colors[imgui.ImGuiCol_TabHovered]                = ImVec4(0.75, 0.75, 0.75, 0.98);
colors[imgui.ImGuiCol_Tab]                       = ImVec4(0.25, 0.25, 0.25, 0.98);
colors[imgui.ImGuiCol_TabSelected]               = ImVec4(0.68, 0.68, 0.68, 1.00);
colors[imgui.ImGuiCol_TabSelectedOverline]       = ImVec4(0.98, 0.98, 0.98, 1.00);
colors[imgui.ImGuiCol_TabDimmed]                 = ImVec4(0.07, 0.10, 0.15, 0.97);
colors[imgui.ImGuiCol_TabDimmedSelected]         = ImVec4(0.42, 0.42, 0.42, 1.00);
colors[imgui.ImGuiCol_TabDimmedSelectedOverline] = ImVec4(0.50, 0.50, 0.50, 0.00);
colors[imgui.ImGuiCol_DockingPreview]            = ImVec4(0.50, 0.50, 0.50, 0.98);
colors[imgui.ImGuiCol_DockingEmptyBg]            = ImVec4(0.25, 0.25, 0.25, 0.98);
colors[imgui.ImGuiCol_PlotLines]                 = ImVec4(0.50, 0.50, 0.50, 0.98);
colors[imgui.ImGuiCol_PlotLinesHovered]          = ImVec4(0.40, 0.40, 0.40, 0.98);
colors[imgui.ImGuiCol_PlotHistogram]             = ImVec4(0.50, 0.50, 0.50, 0.98);
colors[imgui.ImGuiCol_PlotHistogramHovered]      = ImVec4(0.40, 0.40, 0.40, 0.98);
colors[imgui.ImGuiCol_TableHeaderBg]             = ImVec4(0.20, 0.20, 0.20, 1.00);
colors[imgui.ImGuiCol_TableBorderStrong]         = ImVec4(1.00, 1.00, 1.00, 0.20);
colors[imgui.ImGuiCol_TableBorderLight]          = ImVec4(1.00, 1.00, 1.00, 0.20);
colors[imgui.ImGuiCol_TableRowBg]                = ImVec4(1.00, 1.00, 1.00, 0.01);
colors[imgui.ImGuiCol_TableRowBgAlt]             = ImVec4(1.00, 1.00, 1.00, 0.04);
colors[imgui.ImGuiCol_TextLink]                  = ImVec4(0.80, 0.72, 0.58, 1.00);
colors[imgui.ImGuiCol_TextSelectedBg]            = ImVec4(0.98, 0.98, 0.98, 0.35);
colors[imgui.ImGuiCol_DragDropTarget]            = ImVec4(0.75, 0.75, 0.75, 0.98);
colors[imgui.ImGuiCol_NavCursor]                 = ImVec4(0.98, 0.98, 0.98, 1.00);
colors[imgui.ImGuiCol_NavWindowingHighlight]     = ImVec4(1.00, 1.00, 1.00, 0.70);
colors[imgui.ImGuiCol_NavWindowingDimBg]         = ImVec4(0.80, 0.80, 0.80, 0.20);
colors[imgui.ImGuiCol_ModalWindowDimBg]          = ImVec4(0.80, 0.80, 0.80, 0.35);
