import { getSession, signOut } from 'next-auth/react';
import Head from 'next/head';

// gets a prop from getServerSideProps
function User({ user }) {
    return (<>
        {/* Load the <head> HTML for this page! */}
        <Head>
            {/* <!-- Meta + Title --> */}
            <meta charSet="utf-8"/>
            <meta name="viewport" content="width=device-width, initial-scale=1"/>
            <title>🍝 Signed In! 🧪</title>
        </Head>

        <div>
            <h4>User session:</h4>
            <pre>{JSON.stringify(user, null, 2)}</pre>
            <button onClick={() => signOut({ callbackUrl: '/signin' })}>Sign out</button>
        </div>
    </>);
}

export async function getServerSideProps(context) {
    const session = await getSession(context);
    
    // redirect if not authenticated
    if (!session) {
        return {
            redirect: {
                destination: '/signin',
                permanent: false,
            },
        };
    }

    return {
        props: { user: session.user },
    };
}

export default User;