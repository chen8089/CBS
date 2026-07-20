import { LightningElement, api } from 'lwc';

const INFO_ITEMS = [
    {
        key: 'general',
        iconName: 'utility:call',
        title: 'General Services:',
        lines: [
            { key: 'hotline', text: 'Hotline: +65 6565 6363', isEmail: false },
            {
                key: 'email',
                prefix: 'Email: ',
                email: 'consumer_services@creditbureau.com.sg',
                mailto: 'mailto:consumer_services@creditbureau.com.sg',
                isEmail: true
            }
        ]
    },
    {
        key: 'address',
        iconName: 'utility:location',
        title: 'Office Address:',
        lines: [
            { key: 'line1', text: '2 Shenton Way, #20-02 SGX Centre 1', isEmail: false },
            { key: 'line2', text: 'Singapore 068804', isEmail: false }
        ]
    },
    {
        key: 'hours',
        iconName: 'utility:clock',
        title: 'Opening Hours:',
        lines: [
            { key: 'days', text: 'Mon - Fri', isEmail: false },
            { key: 'time', text: '9am - 6pm', isEmail: false }
        ]
    }
];

const CARDS = [
    {
        key: 'corporates',
        title: 'For Corporates',
        body:
            'For business collaborations, partnerships, or general corporate matters, feel free to reach out to our team. We are always open to exploring new opportunities and working together to create meaningful impact.',
        emailIntro: 'Please drop us an email at:',
        email: 'bd@creditbureau.com.sg',
        mailto: 'mailto:bd@creditbureau.com.sg'
    },
    {
        key: 'marketing',
        title: 'For Marketing & PR Matters',
        body:
            'Got a media request or a marketing idea? Our communications team is happy to connect. Contact us for press releases, interviews, brand collaborations, or promotional initiatives.',
        emailIntro: 'Please drop us an email at:',
        email: 'marketing@creditbureau.com.sg',
        mailto: 'mailto:marketing@creditbureau.com.sg'
    },
    {
        key: 'careers',
        title: 'For Career Opportunities',
        body:
            'Interested in joining our team? We are always on the lookout for passionate, driven individuals. Drop us a message to learn more about current openings.',
        emailIntro: 'Please drop us an email at:',
        email: 'hr.cbs@creditbureau.com.sg',
        mailto: 'mailto:hr.cbs@creditbureau.com.sg'
    }
];

export default class ContactUsContent extends LightningElement {
    @api maxWidth = '1280px';
    @api titleText = 'Get In Touch';
    @api backgroundColor = 'transparent';
    @api cardBackgroundColor = '#fff9dd';
    @api iconColor = '#ffb01f';

    infoItems = INFO_ITEMS;
    cards = CARDS;

    renderedCallback() {
        const section = this.template.querySelector('.contact-us-section');
        if (!section) {
            return;
        }
        section.style.setProperty('--contactMaxWidth', this.maxWidth);
        section.style.setProperty('--contactBackgroundColor', this.backgroundColor);
        section.style.setProperty('--contactCardBackgroundColor', this.cardBackgroundColor);
        section.style.setProperty('--contactIconColor', this.iconColor);
    }
}