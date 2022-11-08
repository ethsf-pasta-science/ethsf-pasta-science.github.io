import { Html, Head, Main, NextScript } from 'next/document'

export default function Document() {
  return (
    <Html>
      <Head>
        {/* <!-- Favicons --> */}
        <link rel="apple-touch-icon" sizes="180x180" href="https://ethsf-pasta-science.github.io/favicons/apple-touch-icon.png"/>
        <link rel="icon" type="image/png" sizes="32x32" href="https://ethsf-pasta-science.github.io/favicons/favicon-32x32.png"/>
        <link rel="icon" type="image/png" sizes="16x16" href="https://ethsf-pasta-science.github.io/favicons/favicon-16x16.png"/>
        <link rel="shortcut icon" type="image/x-icon" href="https://ethsf-pasta-science.github.io/favicons/favicon.ico"/>
        {/* <!-- Styles --> */}
        <link href='https://fonts.googleapis.com/css?family=Roboto Mono' rel='stylesheet'/>
        <link href='https://fonts.googleapis.com/css?family=Roboto' rel='stylesheet'/>
        <link href='https://fonts.googleapis.com/css?family=Kanit' rel='stylesheet'/>
        <link href='https://fonts.googleapis.com/css?family=Lobster' rel='stylesheet'/>
        <link rel="stylesheet" href="https://fonts.googleapis.com/icon?family=Material+Icons"/>
      </Head>
      <body>
        <Main />
        <NextScript />
      </body>
    </Html>
  )
}