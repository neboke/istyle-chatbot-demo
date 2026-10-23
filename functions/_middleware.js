// Cloudflare Pagesで、ページを渡す前に認証を確認します。

// エラー内容や認証結果をキャッシュに残さないための設定です。
const PRIVATE_HEADERS = {
  "Cache-Control": "private, no-store, max-age=0",
  "X-Robots-Tag": "noindex, nofollow",
};

// ページを表示せず、エラーを返します。
function errorResponse(status, message, extraHeaders = {}) {
  return new Response(message, {
    status,
    headers: {
      ...PRIVATE_HEADERS,
      "Content-Type": "text/plain; charset=utf-8",
      ...extraHeaders,
    },
  });
}

// ブラウザーにユーザー名・パスワードの入力を求めます。
function unauthorized() {
  return errorResponse(401, "Authentication required.", {
    "WWW-Authenticate": 'Basic realm="Demo", charset="UTF-8"',
  });
}

// 入力内容を同じ長さのデータに変換します。
// 比較にかかる時間から秘密情報を推測されにくくします。
async function digest(value) {
  return crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
}

// アクセスのたびにCloudflare側で実行される入口です。
export async function onRequest(context) {
  // 認証情報はCloudflareの設定から読み取ります。
  const user = context.env.BASIC_AUTH_USER;
  const pass = context.env.BASIC_AUTH_PASS;

  // 設定忘れや不正な設定がある場合は、公開せず500を返します。
  if (
    typeof user !== "string" ||
    typeof pass !== "string" ||
    user.length === 0 ||
    pass.length === 0 ||
    /[:\u0000-\u001f\u007f]/.test(user) ||
    /[\u0000-\u001f\u007f]/.test(pass)
  ) {
    return errorResponse(500, "Authentication is not configured.");
  }

  // ブラウザーから送られた認証情報を取り出します。
  const header = context.request.headers.get("Authorization") || "";

  // 未入力や大きすぎる入力は受け付けません。
  if (!header || header.length > 8192) {
    return unauthorized();
  }

  const match = header.match(
    /^Basic[ \t]+([A-Za-z0-9+/]+={0,2})[ \t]*$/i,
  );

  if (!match) {
    return unauthorized();
  }

  let supplied;

  // 認証情報を文字列へ戻します。不正な形式なら401を返します。
  try {
    const bytes = Uint8Array.from(
      atob(match[1]),
      (character) => character.charCodeAt(0),
    );
    supplied = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    return unauthorized();
  }

  try {
    // 正しい認証情報と入力された情報を、同じ長さに変換します。
    const [expectedHash, suppliedHash] = await Promise.all([
      digest(`${user}:${pass}`),
      digest(supplied),
    ]);

    // Cloudflareが提供する、時間差による推測に配慮した比較です。
    const valid = crypto.subtle.timingSafeEqual(
      expectedHash,
      suppliedHash,
    );

    if (!valid) {
      return unauthorized();
    }

    // 認証に成功した場合だけ、デモのファイルを取得します。
    const result = await context.next();
    const response = new Response(result.body, result);

    // 認証済みのページも、キャッシュへの保存を抑止します。
    for (const [name, value] of Object.entries(PRIVATE_HEADERS)) {
      response.headers.set(name, value);
    }

    return response;
  } catch {
    // 処理が失敗しても、認証を省略してページを表示しません。
    return errorResponse(500, "Authentication service unavailable.");
  }
}
