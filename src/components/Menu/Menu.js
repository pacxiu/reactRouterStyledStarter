import React, { Component } from 'react';
import { Link } from "react-router-dom";

import styled from 'styled-components';
import { sizeVars, media } from "../style-utils/vars";

export default class Menu extends Component {
	render() {
		const Nav = styled.nav`
			position: fixed;
			top: 0;
			left: 0;
			right: 0;
			height: ${sizeVars.navHeight};
			box-shadow: 0 0 11px -2px rgba(251,107,63,.75);
			z-index: 20;
			background-color: #fff;

			${media.mobile`background-color: red;`}


		`;
		
		console.log(media);

		return (
			<Nav>
				<Link to="/">Home</Link>
				<Link to="/test">Marketplace</Link>
			</Nav>
		);
	}
}
