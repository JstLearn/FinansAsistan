// Belirli bir yetki türü gerektiren route'lar için middleware
const yetkiCheck = (yetkiTuru) => (req, res, next) => {
    // Kendi hesabındaysa yetki kontrolü yok
    if (!req.activeAccount || !req.activeAccount.yetki) return next();

    if (req.activeAccount.yetki[yetkiTuru]) return next();

    return res.status(403).json({
        success: false,
        message: `Bu işlem için yetkiniz yok: ${yetkiTuru}`,
        code: 'INSUFFICIENT_PERMISSION'
    });
};

module.exports = yetkiCheck;
