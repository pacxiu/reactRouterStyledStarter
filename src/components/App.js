import React, { Component } from 'react';
import { BrowserRouter as Router, Route, Switch, withRouter } from "react-router-dom";
import styled, { injectGlobal } from 'styled-components';

import logo from '../assets/logo.svg';

// loading SmartContract Details
import { ABI, CONTRACT } from '../data/contractData';

// libraries for SmartContract
import Web3 from 'web3';

// import components
import Footer from './Footer/Footer';
import Menu from './Menu/Menu';

import Home from './Home/Home';
import Marketplace from './Marketplace/Marketplace';

import { Container } from './style-utils/Grid';
import { sizeVars } from './style-utils/vars';

class App extends Component {
	constructor() {
		super();

		this.state = {
			web3: null,
			account: null,
			contract: null,
			network: { current: null, expected: 1, external: true }
		}

		this.initWeb3 = this.initWeb3.bind(this);
		this.initNetworkData = this.initNetworkData.bind(this);
		this.initAccountAddres = this.initAccountAddres.bind(this);
		// this.getContractTokens = this.getContractTokens.bind(this);
	}

	componentDidMount() {
		this.initWeb3();
	}

	initWeb3() {
		let web3 = window.web3;

		if (typeof web3 !== 'undefined') {
		  	web3 = new Web3(web3.currentProvider);
		  	this.setState({ network: {...this.state.network, external: false } });
		} else {
			// web3 = new Web3(new Web3.providers.HttpProvider("https://mainnet.infura.io/Fi6gFcfwLWXX6YUOnke8"));		
		}

		this.setState({ web3 }, () => this.initNetworkData(web3));
	}

	initNetworkData(web3) {
		const eth = web3.eth;

		this.initAccountAddres();

		// get current network
		eth.net.getId().then( (currentNetwork) => {
			let network = { ...this.state.network };
			network.current = currentNetwork;

			if ( (currentNetwork !== this.state.network.expected) && (this.state.network.external === false) ) {
				// const web3 = new Web3(new Web3.providers.HttpProvider("https://mainnet.infura.io/Fi6gFcfwLWXX6YUOnke8"));
				this.setState({ web3, network: {...this.state.network, external: true } }, () => this.initNetworkData(web3));
				return null;
			}

			this.setState({ network });
			return null;
		});

		// get contract
		const contract = new eth.Contract(ABI, CONTRACT);
		this.setState({ contract })
	}

	initAccountAddres() {
		const eth = this.state.web3.eth;
		const { contract } = this.state;

		// setting user account if it is different than current account
		eth.getAccounts().then( (account) => {
			if ( account[0] !== this.state.account ) {
				this.setState({ account: account[0] });
			}
			
			return null;
		});

		if ( contract == null ) { 
			return;
		}

		contract.methods.checkPeriodic().call( function(err, data) {
			console.log(err, data);
		});

		// checking if user switched accounts in interval
		setTimeout(() => {
			this.initAccountAddres();
		}, 5000);
	}

  render() {
  	injectGlobal`
	  body {
	    margin: 0;
	    background: green;
	    padding-top: ${sizeVars.navHeight};
	  }
	`;


  	const Title = styled.h1`
	  font-size: 1.5em;
	  text-align: center;
	  color: palevioletred;
	`;

	const { account, network } = this.state;


    return (
		<div className="App">
			<Menu />

			<Route exact path="/" render={(props) => ( <Home {...props} />)}/>

			<Route exact path="/test" render={(props) => ( <Marketplace {...props} />)}/>


			<Container><Title>Title</Title></Container>

			<Title>{account}</Title>

			<Title>{network.current}</Title>

			<Footer />
		</div>
    );
  }
}

export default App;
