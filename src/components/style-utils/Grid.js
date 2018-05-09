import styled from 'styled-components';
import { centerBlock }  from './mixins';

export const Container = styled.div`
	${ centerBlock() }
	max-width: 1200px;
	background-color: blue;
`;