import { css } from 'styled-components';

export const sizes = {
	mobile: '768px',
	tablet: '1024px',
	laptop: '1280px',
	smallDesktop: '1440px'
};

export const media = Object.keys(sizes).reduce((acc, label) => {
  acc[label] = (...args) => css`
    @media (max-width: ${sizes[label]}) {
      ${css(...args)}
    }
  `

  return acc
}, {})

export const sizeVars = {
	navHeight: `66px`
}

export const colors = {
	accent: `red`
}