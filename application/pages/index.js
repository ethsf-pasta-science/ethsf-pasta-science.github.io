import Head from 'next/head'
import Image from 'next/image'
import styles from '../styles/Home.module.css'
import axios from "axios"
import { getSession } from 'next-auth/react';

// Redirect users to the sign-in page from index.js
export async function getServerSideProps(context) {
  return {
    redirect: {
        destination: '/signin',
        permanent: false,
    },
  };
}

export default function Home() {
  return (
    <div>
      <h1>Never Shown!</h1>
    </div>
  )
};
