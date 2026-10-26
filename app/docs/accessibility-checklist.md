# Accessibility Checklist

Applied to every screen and interactive widget shipped to production.
Reference from `CLAUDE.md` and code review.

## Interactive elements

- [ ] Every icon-only `IconButton` has a `tooltip:` set
- [ ] Every `InkWell` / `GestureDetector` used as a button has a
      `Semantics(label:, button: true)` wrapper or equivalent
- [ ] Tap targets are at least 44×44 (`HD.s48` recommended)
- [ ] Focus order matches visual reading order (top-to-bottom, left-to-right)

## Color & contrast

- [ ] Body text ≥ 4.5:1 vs background (WCAG AA)
- [ ] Large text (18pt+ or 14pt bold) ≥ 3:1
- [ ] Icons and glyphs conveying status pair with a text label — never
      color alone
- [ ] Do **not** pair `HD.inkMuted` on `HD.paperSunken` (contrast 0.96:1) —
      use `HD.inkSoft` on sunken surfaces

## Images

- [ ] `CachedNetworkImage` sets `semanticLabel:` (house title, user name, etc.)
- [ ] Decorative images pass `excludeFromSemantics: true`
- [ ] `imageBuilder` / `placeholder` do not swap the semantic label mid-load

## Text

- [ ] `forceStrutHeight: true` on nav labels and other layouts sensitive to
      baseline drift when weight changes on active state
- [ ] Multi-line text uses `Text.rich` with structural spans rather than
      raw newlines when screen readers need to skip

## Navigation

- [ ] Every screen has a stable back affordance
- [ ] Bottom nav `IndicatorSize` and label baseline stay stable across
      active / inactive transitions
- [ ] Breadcrumbs on 3+ level-deep screens (building → room → contract)

## Testing

Manual pass before merging any screen change:

1. Turn on VoiceOver / TalkBack — swipe through the screen top-to-bottom.
   Every interactive element must be announced with intent (button, link,
   heading, image + label).
2. Increase system font size to XXL — verify no truncation on primary CTAs.
3. Enable "Reduce Motion" — verify no essential feedback is animation-only.

## Density presets (from `design_tokens.dart`)

| Preset | Spacing | Screens |
|---|---|---|
| Dense | s8–s12 | Contract lists, invoice rows, tabular data |
| Balanced | s16–s20 | Property cards, dashboards |
| Spacious | s24+ | Onboarding, empty states |

Do not mix presets within one screen — pick the one that matches the
primary content type.
