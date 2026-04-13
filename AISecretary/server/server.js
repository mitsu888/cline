const express = require("express")
const cors = require("cors")
const rateLimit = require("express-rate-limit")
require("dotenv").config()

const app = express()
const PORT = process.env.PORT || 3000

// --- Middleware ---
app.use(cors())
app.use(express.json({ limit: "1mb" }))

// Rate limiting: 30 requests per minute per IP
const limiter = rateLimit({
	windowMs: 60 * 1000,
	max: 30,
	message: { error: "Too many requests. Please try again later." },
})
app.use("/api/", limiter)

// --- Auth middleware ---
function authenticate(req, res, next) {
	const token = req.headers["authorization"]?.replace("Bearer ", "")
	if (!process.env.API_SECRET_TOKEN) {
		return res.status(500).json({ error: "Server misconfigured: no API_SECRET_TOKEN set" })
	}
	if (token !== process.env.API_SECRET_TOKEN) {
		return res.status(401).json({ error: "Unauthorized" })
	}
	next()
}

// --- Health check ---
app.get("/health", (_req, res) => {
	res.json({ status: "ok", timestamp: new Date().toISOString() })
})

// --- Claude API Relay ---
app.post("/api/chat", authenticate, async (req, res) => {
	const { messages, system, max_tokens } = req.body

	if (!messages || !Array.isArray(messages)) {
		return res.status(400).json({ error: "messages array is required" })
	}

	if (!process.env.CLAUDE_API_KEY) {
		return res.status(500).json({ error: "Server misconfigured: no CLAUDE_API_KEY set" })
	}

	try {
		const response = await fetch("https://api.anthropic.com/v1/messages", {
			method: "POST",
			headers: {
				"Content-Type": "application/json",
				"x-api-key": process.env.CLAUDE_API_KEY,
				"anthropic-version": "2023-06-01",
			},
			body: JSON.stringify({
				model: "claude-sonnet-4-20250514",
				max_tokens: max_tokens || 2048,
				system: system || undefined,
				messages,
			}),
		})

		const data = await response.json()

		if (!response.ok) {
			console.error(`[Relay] Claude API error: ${response.status}`, data)
			return res.status(response.status).json({
				error: data.error?.message || "Claude API error",
			})
		}

		// Return only the text content (strip metadata the client doesn't need)
		const text = data.content
			?.filter((block) => block.type === "text")
			.map((block) => block.text)
			.join("")

		res.json({
			text,
			usage: {
				input_tokens: data.usage?.input_tokens,
				output_tokens: data.usage?.output_tokens,
			},
		})
	} catch (err) {
		console.error("[Relay] Request failed:", err.message)
		res.status(502).json({ error: "Failed to reach Claude API" })
	}
})

// --- Start server ---
app.listen(PORT, () => {
	console.log(`[AI Secretary Relay] Running on port ${PORT}`)
	console.log(`[AI Secretary Relay] API key configured: ${!!process.env.CLAUDE_API_KEY}`)
	console.log(`[AI Secretary Relay] Auth token configured: ${!!process.env.API_SECRET_TOKEN}`)
})
