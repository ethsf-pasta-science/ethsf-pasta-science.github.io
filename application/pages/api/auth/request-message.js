import Moralis from 'moralis';

const config = {
    // domain: process.env.APP_DOMAIN,
    domain: 'auth.app',
    statement: 'Pasta Science Auth',
    // uri: process.env.NEXTAUTH_URL,
    uri: 'http://localhost:3000',
    timeout: 60,
};

export default async function handler(req, res) {
    const { address, chain, network } = req.body;

    // await Moralis.start({ apiKey: process.env.MORALIS_API_KEY });
    await Moralis.start({ apiKey: '5aJhyAlfFDBlpX4brof2QfTLFhQEsIgS1BmU4Djm2P8wiM5CergsmL7QG6rvZagt' });

    try {
        const message = await Moralis.Auth.requestMessage({
            address,
            chain,
            network,
            ...config,
        });

        res.status(200).json(message);
    } catch (error) {
        res.status(400).json({ error });
        console.error(error);
    }
}