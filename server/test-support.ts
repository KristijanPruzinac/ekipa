/**
 * Shared helper for tests that mock the provider with `globalThis.fetch`.
 * Collection sends one batched categorisation request per run; tests that count tip or
 * extraction calls answer it here so those counts stay about their own subject.
 */
export function classificationReply(
  init: RequestInit | undefined,
  category = 'other',
): Response | null {
  let body: { response_format?: { json_schema?: { name?: string } }; messages?: unknown };
  try {
    body = JSON.parse(String(init?.body));
  } catch {
    return null;
  }
  if (body.response_format?.json_schema?.name !== 'event_categories') return null;
  const messages = body.messages as Array<{ role: string; content: string }>;
  const user = JSON.parse(messages.find((message) => message.role === 'user')!.content) as {
    events: Array<{ id: string }>;
  };
  return new Response(
    JSON.stringify({
      choices: [
        {
          finish_reason: 'stop',
          message: {
            role: 'assistant',
            content: JSON.stringify({
              results: user.events.map((event) => ({ id: event.id, category, reason: 'Test.' })),
            }),
          },
        },
      ],
      usage: { cost: 0.0005 },
    }),
    { status: 200 },
  );
}
