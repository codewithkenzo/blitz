import { encoding_for_model, get_encoding, type Tiktoken } from "tiktoken";

let cached: Tiktoken | null = null;

const getEncoder = (): Tiktoken => {
	if (cached) return cached;
	try {
		cached = encoding_for_model("gpt-4o");
	} catch {
		cached = get_encoding("cl100k_base");
	}
	return cached;
};

export const countTokens = (text: string): number => getEncoder().encode(text).length;

export const releaseTokenizer = (): void => {
	if (cached) {
		cached.free();
		cached = null;
	}
};
