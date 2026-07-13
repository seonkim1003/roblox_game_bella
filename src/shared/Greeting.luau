local Greeting = {}

function Greeting.message(source: string): string
	return `Hello from {source}! Rojo is syncing.`
end

return Greeting
