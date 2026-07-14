--!strict

export type Tokens = {
	class: "Phone" | "Tablet" | "Desktop",
	margin: number,
	verticalMargin: number,
	maxContentWidth: number,
	headingSize: number,
	sectionGap: number,
	cornerRadius: number,
	buttonHeight: number,
	motionDuration: number,
}

local ResponsiveTokens = {}

function ResponsiveTokens.forWidth(width: number): Tokens
	if width < 600 then
		return table.freeze({
			class = "Phone",
			margin = 12,
			verticalMargin = 10,
			maxContentWidth = 576,
			headingSize = 20,
			sectionGap = 8,
			cornerRadius = 12,
			buttonHeight = 48,
			motionDuration = 0.15,
		} :: Tokens)
	elseif width < 1000 then
		return table.freeze({
			class = "Tablet",
			margin = 20,
			verticalMargin = 16,
			maxContentWidth = 860,
			headingSize = 22,
			sectionGap = 10,
			cornerRadius = 14,
			buttonHeight = 48,
			motionDuration = 0.15,
		} :: Tokens)
	end
	return table.freeze({
		class = "Desktop",
		margin = 28,
		verticalMargin = 20,
		maxContentWidth = 960,
		headingSize = 24,
		sectionGap = 12,
		cornerRadius = 16,
		buttonHeight = 48,
		motionDuration = 0.15,
	} :: Tokens)
end

function ResponsiveTokens.contentBounds(
	width: number,
	height: number
): (number, number, number, number)
	local tokens = ResponsiveTokens.forWidth(width)
	local contentWidth = math.max(0, math.min(width - tokens.margin * 2, tokens.maxContentWidth))
	local contentHeight = math.max(0, height - tokens.verticalMargin * 2)
	return math.floor((width - contentWidth) / 2),
		tokens.verticalMargin,
		contentWidth,
		contentHeight
end

return table.freeze(ResponsiveTokens)
