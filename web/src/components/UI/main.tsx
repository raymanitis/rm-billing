import {
    ActionIcon,
    Badge,
    Button,
    Card,
    Divider,
    Flex,
    Group,
    Modal,
    NumberInput,
    Select,
    Text,
    TextInput,
    useMantineTheme
} from '@mantine/core';
import {IconCurrencyDollar, IconQuestionMark, IconUserQuestion, IconX} from '@tabler/icons-react';
import useAppVisibilityStore from '../../stores/appVisibilityStore';
import {useEffect, useState} from 'react';
import {useNuiEvent} from '../../hooks/useNuiEvent';
import {fetchNui} from '../../utils/fetchNui';

export function UI() {
    const mantineTheme = useMantineTheme();
    const {showApp, setVisibility} = useAppVisibilityStore();
    const [activeTab, setActiveTab] = useState<'create' | 'history' | 'check'>('history');

    // State for Create Invoice
    const [selectedPlayer, setSelectedPlayer] = useState<string | null>(null);
    const [reason, setReason] = useState('');
    const [amount, setAmount] = useState<number | ''>('');
    const [confirmOpen, setConfirmOpen] = useState(false);
    const [hasPermission, setHasPermission] = useState(false);
    const [hasSearchPermission, setHasSearchPermission] = useState(false);
    const [nearbyPlayers, setNearbyPlayers] = useState<Array<{ id: number, name: string, distance: number }>>([]);

    // State for invoice history
    const [playerInvoices, setPlayerInvoices] = useState<any[]>([]);

    // State for check player invoices
    const [searchPlayerId, setSearchPlayerId] = useState<string | ''>('');
    const [searchedPlayerInvoices, setSearchedPlayerInvoices] = useState<any[]>([]);
    const [isSearching, setIsSearching] = useState(false);

    const handleTabChange = (value: 'create' | 'history' | 'check') => {
        if (value === 'check') {
            setSearchPlayerId('');
            setSearchedPlayerInvoices([]);
        }
        setActiveTab(value);
    };

    // Handle ESC key to close menu
    useEffect(() => {
        const handleKeyDown = (event: KeyboardEvent) => {
            if (event.key === 'Escape' && showApp) {
                closeMenu();
            }
        };

        if (showApp) {
            document.addEventListener('keydown', handleKeyDown);
        }

        return () => {
            document.removeEventListener('keydown', handleKeyDown);
        };
    }, [showApp]);

    // Function to close menu
    const closeMenu = () => {
        setActiveTab('history');
        setVisibility(false);
        fetchNui('hideUI', {});
    };

    // NUI Event Handlers
    useNuiEvent('showUI', (data: { nearbyPlayers?: Array<{ id: number, name: string, distance: number }> }) => {
        setVisibility(true);
        if (data.nearbyPlayers) {
            setNearbyPlayers(data.nearbyPlayers);
        }
    });

    useNuiEvent('setCreateInvoicePermission', (data: { allowed: boolean }) => {
        setHasPermission(data.allowed);
    });

    useNuiEvent('setSearchInvoicePermission', (data: { allowed: boolean }) => {
        setHasSearchPermission(data.allowed);
    });

    useNuiEvent('setPlayerInvoices', (data: { invoices: any[] }) => {
        setPlayerInvoices(data.invoices || []);
    });

    useNuiEvent('setSearchedPlayerInvoices', (data: { invoices: any[], playerName: string }) => {
        setSearchedPlayerInvoices(data.invoices || []);
        setIsSearching(false);
    });

    // Handler for creating invoice
    const handleCreateInvoice = () => {
        if (!hasPermission) return;
        setConfirmOpen(true);
    };

    const handleConfirm = () => {
        // Send the invoice data to the Lua client
        fetchNui('createInvoice', {
            playerId: selectedPlayer,
            reason,
            amount: Number(amount)
        });
        setConfirmOpen(false);
        setSelectedPlayer(null);
        setReason('');
        setAmount('');
        // Hide the UI after creating invoice
        closeMenu();
    };

    // Handler for paying invoice
    const handlePayInvoice = async (invoiceId: string) => {
        const response = await fetchNui('payInvoice', {invoiceId});
        if (response?.success) {
            // Update the local state to mark the invoice as paid
            setPlayerInvoices(prevInvoices => 
                prevInvoices.map(invoice => 
                    invoice.invoice_id === invoiceId 
                        ? {...invoice, status: 'paid'} 
                        : invoice
                )
            );
        }
    };

    // Handler for searching player invoices
    const handleSearchPlayerInvoices = () => {
        if (!hasSearchPermission) return;
        if (!searchPlayerId) return;
        setIsSearching(true);
        fetchNui('searchPlayerInvoices', {playerId: searchPlayerId});
    };

    // Get status color
    const getStatusColor = (status: string) => {
        switch (status) {
            case 'pending':
                return 'yellow';
            case 'paid':
                return 'green';
            case 'cancelled':
                return 'red';
            default:
                return 'gray';
        }
    };

    // Don't render if app is not visible
    if (!showApp) return null;

    return (
        <Flex
            pos="fixed"
            w="100vw"
            h="100vh"
            style={{
                pointerEvents: 'none',
                justifyContent: 'center',
                alignItems: 'center',
                background: 'transparent',
            }}
        >
            <Flex direction="column" align="center" style={{pointerEvents: 'auto'}}>
                <div className="menu-animated" style={{position: 'relative', width: 500, height: 600}}>
                    <Card
                        p="xl"
                        style={{
                            background: mantineTheme.colors.dark[7],
                            borderRadius: 24,
                            border: `2px solid ${mantineTheme.colors.dark[6]}`,
                            boxShadow: '0 8px 32px rgba(0,0,0,0.25)',
                            width: '100%',
                            height: '100%',
                            display: 'flex',
                            flexDirection: 'column',
                            justifyContent: 'flex-start',
                            alignItems: 'center',
                            paddingTop: 0,
                            position: 'relative',
                        }}
                    >
                        {/* Close Button Top Right */}
                        <ActionIcon
                            variant="subtle"
                            color="gray"
                            size={32}
                            className="close-button"
                            style={{
                                position: 'absolute',
                                top: 18,
                                right: 18,
                                zIndex: 10,
                                borderRadius: '8px',
                                background: 'rgba(255, 255, 255, 0.05)',
                                border: '1px solid rgba(255, 255, 255, 0.1)',
                            }}
                            onClick={closeMenu}
                        >
                            <IconX
                                size={18}
                                className="close-button-icon"
                                style={{
                                    color: '#fff',
                                    opacity: 0.8,
                                }}
                            />
                        </ActionIcon>
                        {/*/!* Add space between top and header *!/*/}
                        {/*<div style={{height: 24}}/>*/}
                        {/* Header Section */}
                        <div style={{flexShrink: 0, paddingTop: '12px', paddingBottom: '12px'}}>
                            <Group justify="center" gap="xs">
                                <Button
                                    size="sm"
                                    radius="sm"
                                    variant={activeTab === 'create' ? 'filled' : 'light'}
                                    // color="gray"
                                    onClick={() => handleTabChange('create')}
                                    disabled={!hasPermission}
                                >
                                    Create
                                </Button>
                                <Button
                                    size="sm"
                                    radius="sm"
                                    variant={activeTab === 'history' ? 'filled' : 'light'}
                                    // color="gray"
                                    onClick={() => handleTabChange('history')}
                                >
                                    Your Invoices
                                </Button>
                                <Button
                                    size="sm"
                                    radius="sm"
                                    variant={activeTab === 'check' ? 'filled' : 'light'}
                                    // color="gray"
                                    onClick={() => handleTabChange('check')}
                                    disabled={!hasSearchPermission}
                                >
                                    Search
                                </Button>
                            </Group>
                        </div>

                        {/* Divider under header */}
                        <Divider color={mantineTheme.colors.dark[6]} size="sm" w="100%" mb={24}/>

                        {/* Main UI Section */}
                        <Flex w="100%" style={{
                            flex: 1,
                            position: 'relative',
                            overflowY: 'auto',
                            padding: '0 16px 16px 16px',
                            margin: '0 -16px -16px -16px'
                        }}>
                            {activeTab === 'create' && hasPermission && (
                                <Flex direction="column" h="100%" w="100%"
                                      style={{flex: 1, position: 'relative', padding: 0}}>
                                    <Flex direction="column" gap={30} w={"100%"}
                                          style={{flex: 1, justifyContent: 'flex-start', marginTop: 8}}>
                                        <Select
                                            leftSection={<IconUserQuestion size={20} stroke={2} />}
                                            label="Nearby Players"
                                            placeholder={nearbyPlayers.length > 0 ? "Select a player" : "No players nearby"}
                                            value={selectedPlayer || ''}
                                            onChange={(value) => setSelectedPlayer(value)}
                                            data={nearbyPlayers.map(player => ({
                                                value: player.id.toString(),
                                                label: `${player.name} ${player.id} - ${player.distance}m`
                                            }))}
                                            required
                                            disabled={nearbyPlayers.length === 0}
                                        />
                                        {nearbyPlayers.length === 0 && (
                                            <Text size="sm" c="dimmed" ta="center">
                                                No players within 5m. Move closer.
                                            </Text>
                                        )}
                                        <TextInput
                                            leftSection={<IconQuestionMark size={20} stroke={2} />}
                                            label="Reason"
                                            placeholder="Enter invoice reason"
                                            value={reason}
                                            onChange={(e) => setReason(e.currentTarget.value)}
                                            required
                                        />
                                        <NumberInput
                                            leftSection={<IconCurrencyDollar size={20} stroke={2} />}
                                            label="Amount"
                                            placeholder="1500$"
                                            value={amount}
                                            onChange={value => setAmount(value === '' ? '' : Number(value))}
                                            min={1}
                                            max={100000}
                                            allowDecimal={false}
                                            allowNegative={false}
                                            required
                                        />
                                    </Flex>
                                    <div style={{flexGrow: 1}}/>
                                    <Button
                                        color="blue"
                                        disabled={!selectedPlayer || !reason || !amount || nearbyPlayers.length === 0}
                                        onClick={handleCreateInvoice}
                                        style={{
                                            alignSelf: 'center',
                                            width: '100%',
                                            marginBottom: 24,
                                            marginTop: 62,
                                        }}
                                    >
                                        Create Invoice
                                    </Button>
                                    <Modal
                                        opened={confirmOpen}
                                        onClose={() => setConfirmOpen(false)}
                                        centered
                                        title="Confirm Invoice"
                                    >
                                        <Text mb={16}>
                                            Invoice <b>{`Player ID: ${selectedPlayer}`}</b><br/>
                                            Reason: <b>{reason.length > 30 ? reason.substring(0, 30) + '...' : reason}</b><br/>
                                            Amount: <b>${amount}</b>
                                        </Text>
                                        <Group justify="flex-end">
                                            <Button variant="default" onClick={() => setConfirmOpen(false)}>
                                                Cancel
                                            </Button>
                                            <Button color="blue" onClick={handleConfirm}>
                                                Create
                                            </Button>
                                        </Group>
                                    </Modal>
                                </Flex>
                            )}
                            {activeTab === 'history' && (
                                <Flex direction="column" w="100%" h="100%" style={{flex: 1}}>
                                    <Text c="#fff" size="lg" fw={700} mb={12}>Your Invoices</Text>
                                    <Flex direction="column" gap={8}>
                                        {playerInvoices.length === 0 ? (
                                            <Text c="#bbb" ta="center" mt={20}>You don't have any invoices.</Text>
                                        ) : (
                                            playerInvoices.map((invoice, index) => (
                                                <Card key={index} p="sm" style={{
                                                    background: mantineTheme.colors.dark[6],
                                                    border: `1px solid ${mantineTheme.colors.dark[5]}`,
                                                    minHeight: 'fit-content'
                                                }}>
                                                    <Flex justify="space-between" align="center" mb={6}>
                                                        <Text size="sm" fw={600}
                                                              c="#fff">Invoice #{invoice.invoice_id}</Text>
                                                        <Badge variant="light"
                                                               color={getStatusColor(invoice.status)} size="lg"
                                                               radius="sm"
                                                               style={{textTransform: 'uppercase'}}>{invoice.status}</Badge>
                                                    </Flex>
                                                    <Text size="xs" c="#ccc" mb={2} style={{
                                                        overflow: 'hidden',
                                                        textOverflow: 'ellipsis',
                                                        whiteSpace: 'nowrap'
                                                    }}>
                                                        From: {invoice.from_name} ({invoice.from_job})
                                                    </Text>
                                                    <Text size="xs" c="#ccc" mb={2} style={{
                                                        overflow: 'hidden',
                                                        textOverflow: 'ellipsis',
                                                        whiteSpace: 'nowrap'
                                                    }}>
                                                        Reason: {invoice.reason.length > 30 ? invoice.reason.substring(0, 30) + '...' : invoice.reason}
                                                    </Text>
                                                    <Group justify="space-between" align="center" mt="sm">
                                                        <Text size="xs" c="dimmed">
                                                            {new Date(invoice.created_at).toLocaleDateString("lv-LV")}
                                                        </Text>
                                                        <Badge color="green" variant="light" size="lg" radius="sm">
                                                            ${invoice.amount}
                                                        </Badge>
                                                    </Group>
                                                    {invoice.status === 'pending' && (
                                                        <Button
                                                            size="xs"
                                                            color="green"
                                                            mt={6}
                                                            onClick={() => handlePayInvoice(invoice.invoice_id)}
                                                        >
                                                            Pay
                                                        </Button>
                                                    )}
                                                </Card>
                                            ))
                                        )}
                                    </Flex>
                                </Flex>
                            )}
                            {activeTab === 'check' && hasPermission && (
                                <Flex direction="column" w="100%" h="100%" style={{flex: 1}}>
                                    <Text c="#fff" size="lg" fw={700} mb={12}>Search Invoices</Text>

                                    {/* Search Section */}
                                    <Flex gap={8} mb={12}>
                                        <TextInput
                                            placeholder="Enter ID (e.g., HHGUQ367, EV58R12)"
                                            value={searchPlayerId}
                                            onChange={(event) => setSearchPlayerId(event.currentTarget.value)}
                                            min={1}
                                            style={{flex: 1}}
                                            size="sm"
                                        />
                                        <Button
                                            size="sm"
                                            onClick={handleSearchPlayerInvoices}
                                            disabled={!searchPlayerId || isSearching}
                                        >
                                            {isSearching ? 'Searching...' : 'Search'}
                                        </Button>
                                    </Flex>

                                    {/* Results Section */}
                                    <Flex direction="column" gap={8}>
                                        {searchPlayerId && searchedPlayerInvoices.length > 0 ? (
                                            // Show searched player invoices
                                            <>
                                                <Text size="sm" c="#ccc" mb={8}>Results for ID: {searchPlayerId}</Text>
                                                {searchedPlayerInvoices.map((invoice, index) => (
                                                    <Card key={index} p="sm" style={{
                                                        background: mantineTheme.colors.dark[6],
                                                        border: `1px solid ${mantineTheme.colors.dark[5]}`,
                                                        minHeight: 'fit-content'
                                                    }}>
                                                        <Flex justify="space-between" align="center" mb={6}>
                                                            <Text size="sm" fw={600}
                                                                  c="#fff">Invoice #{invoice.invoice_id}</Text>
                                                            <Badge variant="light"
                                                                   color={getStatusColor(invoice.status)}
                                                                   radius="sm"
                                                                   style={{textTransform: 'uppercase'}}>{invoice.status}</Badge>
                                                        </Flex>
                                                        <Text size="xs" c="#ccc" mb={2} style={{
                                                            overflow: 'hidden',
                                                            textOverflow: 'ellipsis',
                                                            whiteSpace: 'nowrap'
                                                        }}>
                                                            Issued
                                                            by: {invoice.from_name} ({invoice.from_job ?? "Unknown"})
                                                        </Text>
                                                        <Text size="xs" c="#ccc" mb={2} style={{
                                                            overflow: 'hidden',
                                                            textOverflow: 'ellipsis',
                                                            whiteSpace: 'nowrap'
                                                        }}>
                                                            Issued
                                                            to: {invoice.to_name} ({invoice.to_player ?? "Unknown"})
                                                        </Text>
                                                        <Text size="xs" c="#ccc" mb={2} style={{
                                                            overflow: 'hidden',
                                                            textOverflow: 'ellipsis',
                                                            whiteSpace: 'nowrap'
                                                        }}>
                                                            Reason: {invoice.reason.length > 25 ? invoice.reason.substring(0, 25) + '...' : invoice.reason}
                                                        </Text>
                                                        <Group justify="space-between" align="center" mt="sm">
                                                            <Text size="xs" c="dimmed">
                                                                {new Date(invoice.created_at).toLocaleDateString('lv-LV')}
                                                            </Text>
                                                            <Badge color="green" variant="light" size="lg" radius="sm">
                                                                ${invoice.amount}
                                                            </Badge>
                                                        </Group>
                                                    </Card>
                                                ))}
                                            </>
                                        ) : searchPlayerId && !isSearching ? (
                                            <Text c="#bbb" ta="center" mt={20}>No invoices found for
                                                ID: {searchPlayerId}</Text>
                                        ) : (
                                            <Text c="#bbb" ta="center" mt={20}>Enter a ID to search for their
                                                invoices.</Text>
                                        )}
                                    </Flex>
                                </Flex>
                            )}
                        </Flex>
                    </Card>
                </div>
            </Flex>
        </Flex>
    );
}