const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

function calcularDistanciaKm(lat1, lon1, lat2, lon2) {
  const r = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return r * c;
}

exports.enviarPushOfertaRelampago = onDocumentCreated(
  "produtos/{produtoId}",
  async (event) => {
    const produto = event.data.data();

    if (!produto) {
      logger.info("Produto vazio.");
      return;
    }

    if (produto.ehRelampago !== true) {
      logger.info("Produto não é oferta relâmpago.");
      return;
    }

    const latitudeOferta = produto.latitude;
    const longitudeOferta = produto.longitude;

    if (latitudeOferta == null || longitudeOferta == null) {
      logger.info("Oferta relâmpago sem latitude/longitude.");
      return;
    }

    const tokensSnapshot = await admin
      .firestore()
      .collection("tokens_notificacao")
      .where("notificacoesAtivas", "==", true)
      .get();

    const mensagens = [];

    tokensSnapshot.forEach((doc) => {
      const dados = doc.data();

      const token = dados.token;
      const latitudeUsuario = dados.latitude;
      const longitudeUsuario = dados.longitude;
      const raioKm = dados.raioKm || 5;

      if (!token || latitudeUsuario == null || longitudeUsuario == null) {
        return;
      }

      const distancia = calcularDistanciaKm(
        latitudeOferta,
        longitudeOferta,
        latitudeUsuario,
        longitudeUsuario
      );

      if (distancia <= raioKm) {
        mensagens.push({
          token: token,
          notification: {
            title: "Oferta relâmpago no Compra Certa!",
            body: `${produto.nome || "Produto em oferta"} por R$ ${
              produto.preco || ""
            }`,
          },
          data: {
            tipo: "oferta_relampago",
            produtoId: event.params.produtoId,
          },
        });
      }
    });

    if (mensagens.length === 0) {
      logger.info("Nenhum consumidor próximo encontrado.");
      return;
    }

    const resultado = await admin.messaging().sendEach(mensagens);

    logger.info("Push de oferta relâmpago enviado.", {
      total: mensagens.length,
      sucesso: resultado.successCount,
      falha: resultado.failureCount,
    });
  }
);