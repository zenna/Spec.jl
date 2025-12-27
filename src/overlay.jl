using CassetteOverlay

@MethodTable Spectable;                     # exported by Base.Experimental
const SpecPass = @overlaypass Spectable;    # compiled at precompile‑time

""" Run `f(args...; kwargs...)` **under** the Spec overlay. """
function specapply(f, args...; kwargs...)
    SpecPass() do                       # activates overlays in `Spectable`
        if Spec._has_overlay_bypass(f)
            Spec.prepostcall(f, args...; kwargs...)
        else
            f(args...; kwargs...)
        end
    end
end
