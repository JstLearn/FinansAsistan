const GLOBAL_FONT_FAMILY = '"Kalam", "Comic Sans MS", cursive, sans-serif';
const APP_URL = process.env.APP_URL || 'http://localhost:9999';

// Ortak email base template
const getEmailBase = (title, content) => {
    return `
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta name="color-scheme" content="dark">
            <meta name="supported-color-schemes" content="dark">
            <title>${title}</title>
            <style>
                :root {
                    color-scheme: dark;
                    supported-color-schemes: dark;
                }
                * {
                    color-scheme: dark !important;
                }
                @media (prefers-color-scheme: light) {
                    body, div, p, h1, h2, h3, h4, h5, h6 {
                        background-color: #1a1f25 !important;
                        color: #fff !important;
                    }
                }
            </style>
        </head>
        <body style="
            margin: 0 !important;
            padding: 0 !important;
            font-family: ${GLOBAL_FONT_FAMILY};
            background-color: #0a0e27 !important;
            background: #0a0e27 !important;
            min-height: 100vh !important;
            display: flex !important;
            align-items: center !important;
            justify-content: center !important;
        " bgcolor="#0a0e27">
            <div style="
                max-width: 600px !important;
                width: 100% !important;
                margin: 40px auto !important;
                background-color: #1a1f25 !important;
                background: #1a1f25 !important;
                border-radius: 16px !important;
                border: 1px solid #007bff !important;
                box-shadow: 0 8px 32px rgba(0, 123, 255, 0.3) !important;
                overflow: hidden !important;
            " bgcolor="#1a1f25">
                <!-- Header -->
                <div style="
                    background-color: #1e2832 !important;
                    background: #1e2832 !important;
                    padding: 32px 24px !important;
                    text-align: center !important;
                    border-bottom: 1px solid #007bff !important;
                " bgcolor="#1e2832">
                    <h1 style="
                        margin: 0 !important;
                        font-size: 28px !important;
                        font-weight: bold !important;
                        color: #4da3ff !important;
                    " color="#4da3ff">
                        FinansAsistan
                    </h1>
                    <p style="
                        margin: 8px 0 0 0 !important;
                        font-size: 14px !important;
                        color: #999 !important;
                        letter-spacing: 1px !important;
                    " color="#999">
                        ${title}
                    </p>
                </div>

                <!-- Content -->
                <div style="
                    padding: 32px 24px !important;
                    background-color: #1a1f25 !important;
                    background: #1a1f25 !important;
                " bgcolor="#1a1f25">
                    ${content}
                </div>

                <!-- Footer -->
                <div style="
                    background-color: #1e2832 !important;
                    background: #1e2832 !important;
                    padding: 20px 24px !important;
                    text-align: center !important;
                    border-top: 1px solid #007bff !important;
                " bgcolor="#1e2832">
                    <p style="
                        margin: 0 !important;
                        font-size: 12px !important;
                        color: #666 !important;
                        line-height: 1.6 !important;
                    " color="#666">
                        Bu bir otomatik maildir, lütfen cevaplamayınız.<br>
                        © 2025 FinansAsistan - Tüm hakları saklıdır.
                    </p>
                </div>
            </div>
        </body>
        </html>
    `;
};

// Yetkilendirme email template
const getAuthorizationEmail = (yetkiVerenEmail, yetkiliEmail, yetkiler) => {
    const yetkiListesi = [];
    if (yetkiler.varlik_ekleme) yetkiListesi.push('Varlık Ekleme');
    if (yetkiler.gelir_ekleme) yetkiListesi.push('Gelir Ekleme');
    if (yetkiler.harcama_borc_ekleme) yetkiListesi.push('Harcama-Borç Ekleme');
    if (yetkiler.istek_ekleme) yetkiListesi.push('İstek Ekleme');
    if (yetkiler.hatirlatma_ekleme) yetkiListesi.push('Hatırlatma Ekleme');

    const yetkiHtml = yetkiListesi.map(y => `
        <div style="
            background-color: #1e3a21 !important;
            background: #1e3a21 !important;
            padding: 12px 16px !important;
            margin: 8px 0 !important;
            border-radius: 8px !important;
            border-left: 3px solid #28a745 !important;
            color: #5cd672 !important;
            font-size: 14px !important;
            font-weight: 500 !important;
        " bgcolor="#1e3a21" color="#5cd672">
            ✓ ${y}
        </div>
    `).join('');

    const content = `
        <p style="
            color: rgba(255, 255, 255, 0.9) !important;
            font-size: 16px;
            line-height: 1.8;
            margin: 0 0 24px 0;
        ">
        </p>
        
        <div style="
            background-color: #1e3240 !important;
            background: #1e3240 !important;
            padding: 20px !important;
            border-radius: 12px !important;
            border: 1px solid #007bff !important;
            margin-bottom: 24px !important;
        " bgcolor="#1e3240">
            <p style="
                color: #fff !important;
                font-size: 15px !important;
                line-height: 1.8 !important;
                margin: 0 !important;
            " color="#fff">
                <strong style="color: #4da3ff !important;" color="#4da3ff">${yetkiVerenEmail}</strong> 
                adlı kullanıcı, FinansAsistan uygulamasında sizin adınıza veri ekleme yetkisi verdi.
            </p>
        </div>

        <h3 style="
            color: #fff !important;
            font-size: 18px !important;
            margin: 0 0 16px 0 !important;
            font-weight: 600 !important;
        " color="#fff">
            Verilen Yetkiler:
        </h3>

        ${yetkiHtml}

        <div style="
            background-color: #3a3020 !important;
            background: #3a3020 !important;
            padding: 16px !important;
            border-radius: 8px !important;
            border-left: 3px solid #ffc107 !important;
            margin: 24px 0 !important;
        " bgcolor="#3a3020">
            <p style="
                color: #ffdb4d !important;
                font-size: 13px !important;
                line-height: 1.6 !important;
                margin: 0 !important;
            " color="#ffdb4d">
                <strong>⚠️ Not:</strong> Eklenen verileri göremez veya düzenleyemezsiniz, 
                sadece sizin adınıza eklenecektir.
            </p>
        </div>

        <div style="text-align: center; margin-top: 32px;">
            <a href="${APP_URL}" style="
                display: inline-block !important;
                padding: 14px 32px !important;
                background-color: #007bff !important;
                background: #007bff !important;
                color: #fff !important;
                text-decoration: none !important;
                border-radius: 25px !important;
                font-size: 16px !important;
                font-weight: bold !important;
                box-shadow: 0 8px 16px rgba(0, 123, 255, 0.4) !important;
                border: 2px solid #0056b3 !important;
            " bgcolor="#007bff" color="#fff">
                🚀 FinansAsistan'a Git
            </a>
            <p style="
                color: #888 !important;
                font-size: 12px !important;
                margin-top: 12px !important;
            " color="#888">
            </p>
        </div>
    `;

    return getEmailBase('Yetkilendirme Bildirimi', content);
};

// Doğrulama kodu email template
const getVerificationEmail = (verificationCode) => {
    const content = `
        <p style="
            color: #fff !important;
            font-size: 16px !important;
            line-height: 1.8 !important;
            margin: 0 0 24px 0 !important;
        " color="#fff">
        </p>
        
        <div style="
            background-color: #1e3240 !important;
            background: #1e3240 !important;
            padding: 20px !important;
            border-radius: 12px !important;
            border: 1px solid #007bff !important;
            margin-bottom: 24px !important;
        " bgcolor="#1e3240">
            <p style="
                color: #fff !important;
                font-size: 15px !important;
                line-height: 1.8 !important;
                margin: 0 0 16px 0 !important;
            " color="#fff">
                FinansAsistan'a hoş geldiniz! Hesabınızı doğrulamak için aşağıdaki kodu kullanın:
            </p>

            <div style="
                background-color: #1e3a21 !important;
                background: #1e3a21 !important;
                padding: 24px !important;
                border-radius: 12px !important;
                text-align: center !important;
                border: 2px solid #28a745 !important;
                margin: 20px 0 !important;
            " bgcolor="#1e3a21">
                <div style="
                    font-size: 48px !important;
                    font-weight: bold !important;
                    color: #5cd672 !important;
                    letter-spacing: 8px !important;
                    font-family: 'Courier New', monospace !important;
                " color="#5cd672">
                    ${verificationCode}
                </div>
                <p style="
                    color: #999 !important;
                    font-size: 12px !important;
                    margin: 12px 0 0 0 !important;
                " color="#999">
                    Bu kod 10 dakika süreyle geçerlidir
                </p>
            </div>
        </div>

        <div style="
            background-color: #3a3020 !important;
            background: #3a3020 !important;
            padding: 16px !important;
            border-radius: 8px !important;
            border-left: 3px solid #ffc107 !important;
            margin: 24px 0 !important;
        " bgcolor="#3a3020">
            <p style="
                color: #ffdb4d !important;
                font-size: 13px !important;
                line-height: 1.6 !important;
                margin: 0 !important;
            " color="#ffdb4d">
                <strong>⚠️ Güvenlik:</strong> Bu kodu kimseyle paylaşmayın. 
                Eğer bu işlemi siz yapmadıysanız, bu e-postayı görmezden gelebilirsiniz.
            </p>
        </div>

        <div style="text-align: center; margin-top: 32px;">
            <a href="${APP_URL}" style="
                display: inline-block !important;
                padding: 14px 32px !important;
                background-color: #007bff !important;
                background: #007bff !important;
                color: #fff !important;
                text-decoration: none !important;
                border-radius: 25px !important;
                font-size: 16px !important;
                font-weight: bold !important;
                box-shadow: 0 8px 16px rgba(0, 123, 255, 0.4) !important;
                border: 2px solid #0056b3 !important;
            " bgcolor="#007bff" color="#fff">
                🚀 Hesabımı Doğrula
            </a>
        </div>
    `;

    return getEmailBase('Hesap Doğrulama', content);
};

module.exports = {
    getAuthorizationEmail,
    getVerificationEmail
};

